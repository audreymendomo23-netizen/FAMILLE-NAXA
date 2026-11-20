package cm.naxa.naxaservices

import cm.naxa.naxaservices.data.LocalAccountingEntry
import cm.naxa.naxaservices.data.LocalManagementRecord
import cm.naxa.naxaservices.data.LocalSale
import java.time.LocalDate
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PerformanceEngineTest {
    private val zone = ZoneId.of("UTC")
    private val today = LocalDate.of(2026, 11, 20)
    private val now = today.atTime(12, 0).atZone(zone).toInstant().toEpochMilli()

    private fun millis(date: LocalDate) = date.atTime(12, 0).atZone(zone).toInstant().toEpochMilli()

    private fun sale(
        id: String,
        date: LocalDate,
        amount: Long = 10_000L,
        cogs: Long = 6_000L,
        stockId: String? = "sku-1"
    ) = LocalSale(
        id = id,
        orgId = "org-1",
        siteId = "site-1",
        cashSessionId = "cash-1",
        saleNumber = "S-" + id,
        description = "Vente " + id,
        totalXaf = amount,
        paymentMethod = "cash",
        status = "confirmed",
        actorMemberId = "member-1",
        createdAtMillis = millis(date),
        inventoryItemId = stockId,
        stockQuantity = if (stockId == null) null else 1.0,
        unitCostAtSaleXaf = if (stockId == null) 0L else cogs,
        costOfGoodsXaf = if (stockId == null) 0L else cogs,
        costSnapshotComplete = stockId != null && cogs > 0L
    )

    private fun expense(amount: Long, date: LocalDate = today) = LocalAccountingEntry(
        id = "expense-" + amount + "-" + date.dayOfMonth,
        orgId = "org-1",
        siteId = "site-1",
        journalBatchId = "batch-expense",
        sourceType = "expense",
        sourceId = "expense-" + amount,
        eventCode = "expense-recorded",
        debitAccount = "OPERATING_EXPENSE:RENT",
        creditAccount = "CASH_REGISTER",
        amountXaf = amount,
        description = "Loyer",
        actorMemberId = "member-1",
        occurredAtMillis = millis(date)
    )

    private fun goal(period: String, target: Long, created: LocalDate = today, siteId: String = "site-1") = LocalManagementRecord(
        id = "goal-" + period + "-" + siteId,
        orgId = "org-1",
        siteId = siteId,
        recordType = "business_goal",
        reference = "OBJ-" + period,
        title = "Objectif " + period,
        counterparty = period,
        amountXaf = target,
        paidXaf = 0L,
        dueAtMillis = null,
        status = "open",
        metadataJson = "{}",
        actorMemberId = "member-1",
        createdAtMillis = millis(created)
    )

    @Test
    fun confirmedSalesRemainTurnoverAndSupplierPayablesStaySeparate() {
        val result = NaxaPerformanceEngine.analyze(
            sales = listOf(sale("1", today, 100_000L, 60_000L)),
            accountingEntries = emptyList(),
            objectives = emptyList(),
            supplierPayablesXaf = 90_000L,
            lowStockCount = 0,
            nowMillis = now,
            zone = zone
        )
        assertEquals(100_000L, result.revenueXaf)
        assertEquals(60_000L, result.costOfGoodsXaf)
        assertEquals(40_000L, result.grossProfitXaf)
        assertEquals(40.0, result.grossMarginPercent!!, 0.001)
        assertEquals(90_000L, result.supplierPayablesXaf)
    }

    @Test
    fun operatingExpensesReduceProfitProxyButNotRevenue() {
        val result = NaxaPerformanceEngine.analyze(
            sales = listOf(sale("1", today, 100_000L, 60_000L)),
            accountingEntries = listOf(expense(5_000L)),
            objectives = emptyList(),
            supplierPayablesXaf = 0L,
            lowStockCount = 0,
            nowMillis = now,
            zone = zone
        )
        assertEquals(100_000L, result.revenueXaf)
        assertEquals(40_000L, result.grossProfitXaf)
        assertEquals(5_000L, result.operatingExpensesXaf)
        assertEquals(35_000L, result.operatingProfitProxyXaf)
    }

    @Test
    fun legacyStockSaleWithoutCostDoesNotClaimAccurateMargin() {
        val result = NaxaPerformanceEngine.analyze(
            sales = listOf(sale("legacy", today, 20_000L, 0L)),
            accountingEntries = emptyList(),
            objectives = emptyList(),
            supplierPayablesXaf = 0L,
            lowStockCount = 0,
            nowMillis = now,
            zone = zone
        )
        assertNull(result.grossMarginPercent)
        assertEquals(1, result.uncostedStockSalesCount)
    }

    @Test
    fun dailyMonthlyAnnualTrendsAndForecastsAreProduced() {
        val sales = (0L..19L).map { offset ->
            sale("day-" + offset, today.minusDays(offset), 10_000L, 6_000L)
        }
        val goals = listOf(
            goal("daily", 50_000L),
            goal("monthly", 500_000L, today.withDayOfMonth(1)),
            goal("annual", 20_000_000L, today.withDayOfYear(1))
        )
        val result = NaxaPerformanceEngine.analyze(sales, emptyList(), goals, 0L, 0, now, zone)
        assertEquals(14, result.dailyTrend.size)
        assertEquals(12, result.monthlyTrend.size)
        assertEquals(5, result.yearlyTrend.size)
        assertEquals(200_000L, result.month.actualXaf)
        assertEquals(50_000L, result.day.targetXaf)
        assertNotNull(result.month.targetGapXaf)
        assertTrue(result.month.projectedXaf >= result.month.actualXaf)
        assertTrue(
            "The monthly recovery action must refer to the active month label.",
            result.recoveryActions.any { it.title.contains("objectif " + result.month.label) }
        )
    }

    @Test
    fun pendingAndCancelledSalesAreNotCountedAsTurnover() {
        val pending = sale("pending", today).copy(status = "pending")
        val cancelled = sale("cancelled", today).copy(status = "cancelled")
        val result = NaxaPerformanceEngine.analyze(listOf(pending, cancelled), emptyList(), emptyList(), 0L, 0, now, zone)
        assertEquals(0L, result.revenueXaf)
        assertEquals(0, result.dataCoverageDays)
    }

    @Test
    fun networkObjectivesSumLatestApprovedBaselinePerSiteAndRecoverAllPeriods() {
        val sales = listOf(
            sale("site-1", today, 10_000L, 5_000L).copy(siteId = "site-1"),
            sale("site-2", today, 20_000L, 10_000L).copy(siteId = "site-2")
        )
        val objectives = listOf(
            goal("daily", 50_000L, today, "site-1"),
            goal("daily", 70_000L, today, "site-2"),
            goal("monthly", 500_000L, today.withDayOfMonth(1), "site-1"),
            goal("monthly", 300_000L, today.withDayOfMonth(1), "site-2"),
            goal("annual", 20_000_000L, today.withDayOfYear(1), "site-1"),
            goal("annual", 15_000_000L, today.withDayOfYear(1), "site-2")
        )
        val result = NaxaPerformanceEngine.analyze(
            sales, emptyList(), objectives, 0L, 0, now, zone
        )
        assertEquals(120_000L, result.day.targetXaf)
        assertEquals(800_000L, result.month.targetXaf)
        assertEquals(35_000_000L, result.year.targetXaf)
        assertTrue(result.recoveryActions.any { it.title.contains("objectif " + result.day.label) })
        assertTrue(result.recoveryActions.any { it.title.contains("objectif " + result.month.label) })
        assertTrue(result.recoveryActions.any { it.title.contains("objectif " + result.year.label) })
    }

    @Test
    fun supplierReceiptsAndPaymentsAffectTheCorrectFinancialLinesWithoutInflatingRevenue() {
        fun entry(
            id: String, sourceType: String, eventCode: String,
            debit: String, credit: String, amount: Long
        ) = LocalAccountingEntry(
            id = id,
            orgId = "org-1",
            siteId = "site-1",
            journalBatchId = "batch-" + id,
            sourceType = sourceType,
            sourceId = id,
            eventCode = eventCode,
            debitAccount = debit,
            creditAccount = credit,
            amountXaf = amount,
            description = id,
            actorMemberId = "member-1",
            occurredAtMillis = now
        )

        val entries = listOf(
            entry("stock-receipt", "purchase_receipt", "goods_received", "INVENTORY_ASSET", "SUPPLIER_PAYABLE", 100_000L),
            entry("expense-receipt", "purchase_receipt", "expense_received", "OPERATING_EXPENSE_PURCHASE", "SUPPLIER_PAYABLE", 20_000L),
            entry("asset-receipt", "purchase_receipt", "asset_received", "FIXED_ASSET", "SUPPLIER_PAYABLE", 30_000L),
            entry("recoverable-tax", "purchase_receipt", "recoverable_tax", "INPUT_TAX_RECEIVABLE", "SUPPLIER_PAYABLE", 5_000L),
            entry("supplier-payment", "supplier_payment", "payable_settlement", "SUPPLIER_PAYABLE", "BANK", 50_000L)
        )
        val result = NaxaPerformanceEngine.analyze(
            sales = listOf(sale("sale", today, 100_000L, 60_000L)),
            accountingEntries = entries,
            objectives = emptyList(),
            supplierPayablesXaf = 105_000L,
            lowStockCount = 0,
            nowMillis = now,
            zone = zone
        )

        assertEquals(100_000L, result.revenueXaf)
        assertEquals(20_000L, result.operatingExpensesXaf)
        assertEquals(20_000L, result.operatingProfitProxyXaf)
        assertEquals(100_000L, result.currentMonthSupplierStockPurchasesXaf)
        assertEquals(20_000L, result.currentMonthSupplierOperatingPurchasesXaf)
        assertEquals(30_000L, result.currentMonthSupplierFixedAssetsXaf)
        assertEquals(50_000L, result.currentMonthSupplierPaymentsXaf)
        assertEquals(105_000L, result.supplierPayablesXaf)
    }

    @Test
    fun performanceCalendarUsesDoualaLocalDateAcrossUtcMidnight() {
        val utc = ZoneId.of("UTC")
        val boundary = LocalDate.of(2026, 11, 20).atTime(23, 30).atZone(utc).toInstant().toEpochMilli()
        val saleAtBoundary = sale("douala-boundary", today, 12_000L, 7_000L).copy(createdAtMillis = boundary)
        val result = NaxaPerformanceEngine.analyze(
            sales = listOf(saleAtBoundary),
            accountingEntries = emptyList(),
            objectives = emptyList(),
            supplierPayablesXaf = 0L,
            lowStockCount = 0,
            nowMillis = boundary,
            zone = ZoneId.of("Africa/Douala")
        )
        assertEquals("2026-11-21", result.day.label)
        assertEquals(12_000L, result.day.actualXaf)
        assertEquals("2026-11-21", result.dailyTrend.last().label)
    }

    @Test
    fun financialProfitabilityTrendsCompareRevenueCostsAndSupplierFlows() {
        val previousMonthDay = today.minusMonths(1).withDayOfMonth(10)
        val previousYearDay = today.minusYears(1)
        val sales = listOf(
            sale("finance-today", today, 100_000L, 60_000L),
            sale("finance-yesterday", today.minusDays(1), 80_000L, 50_000L),
            sale("finance-prior-month", previousMonthDay, 50_000L, 30_000L),
            sale("finance-prior-year", previousYearDay, 60_000L, 35_000L)
        )
        fun journal(
            id: String, date: LocalDate, sourceType: String, eventCode: String,
            debit: String, credit: String, amount: Long
        ) = expense(amount, date).copy(
            id = id,
            sourceType = sourceType,
            sourceId = id,
            eventCode = eventCode,
            debitAccount = debit,
            creditAccount = credit
        )
        val entries = listOf(
            journal("rent-today", today, "expense", "recorded", "OPERATING_EXPENSE:RENT", "CASH_REGISTER", 10_000L),
            journal("rent-yesterday", today.minusDays(1), "expense", "recorded", "OPERATING_EXPENSE:RENT", "CASH_REGISTER", 8_000L),
            journal("rent-prior-month", previousMonthDay, "expense", "recorded", "OPERATING_EXPENSE:RENT", "CASH_REGISTER", 5_000L),
            journal("rent-prior-year", previousYearDay, "expense", "recorded", "OPERATING_EXPENSE:RENT", "CASH_REGISTER", 6_000L),
            journal("stock-receipt-today", today, "purchase_receipt", "goods_received", "INVENTORY_ASSET", "SUPPLIER_PAYABLE", 25_000L),
            journal("consumable-receipt-today", today, "purchase_receipt", "expense_received", "OPERATING_EXPENSE_PURCHASE", "SUPPLIER_PAYABLE", 2_000L),
            journal("supplier-payment-today", today, "supplier_payment", "payable_settlement", "SUPPLIER_PAYABLE", "BANK", 7_000L)
        )
        val result = NaxaPerformanceEngine.analyze(
            sales = sales,
            accountingEntries = entries,
            objectives = emptyList(),
            supplierPayablesXaf = 123_000L,
            lowStockCount = 0,
            nowMillis = now,
            zone = zone
        )
        val daily = result.dailyFinancialTrend.last()
        assertEquals(14, result.dailyFinancialTrend.size)
        assertEquals(100_000L, daily.revenueXaf)
        assertEquals(80_000L, daily.comparableRevenueXaf)
        assertEquals(40_000L, daily.grossProfitXaf)
        assertEquals(30_000L, daily.comparableGrossProfitXaf)
        assertEquals(12_000L, daily.operatingExpensesXaf)
        assertEquals(8_000L, daily.comparableOperatingExpensesXaf)
        assertEquals(28_000L, daily.operatingResultXaf)
        assertEquals(25_000L, daily.supplierStockPurchasesXaf)
        assertEquals(2_000L, daily.supplierOperatingPurchasesXaf)
        assertEquals(7_000L, daily.supplierPaymentsXaf)

        val monthly = result.monthlyFinancialTrend.last()
        assertEquals(12, result.monthlyFinancialTrend.size)
        assertEquals(180_000L, monthly.revenueXaf)
        assertEquals(50_000L, monthly.comparableRevenueXaf)
        assertEquals(70_000L, monthly.grossProfitXaf)
        assertEquals(20_000L, monthly.operatingExpensesXaf)
        assertEquals(50_000L, monthly.operatingResultXaf)

        val annual = result.yearlyFinancialTrend.last()
        assertEquals(5, result.yearlyFinancialTrend.size)
        assertEquals(230_000L, annual.revenueXaf)
        assertEquals(60_000L, annual.comparableRevenueXaf)
        assertEquals(90_000L, annual.grossProfitXaf)
        assertEquals(25_000L, annual.operatingExpensesXaf)
        assertEquals(65_000L, annual.operatingResultXaf)
    }

}
