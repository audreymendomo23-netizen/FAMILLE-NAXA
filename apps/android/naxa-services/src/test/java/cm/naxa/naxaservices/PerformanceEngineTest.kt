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

}
