package cm.naxa.naxaservices

import cm.naxa.naxaservices.data.LocalAccountingEntry
import cm.naxa.naxaservices.data.LocalManagementRecord
import cm.naxa.naxaservices.data.LocalSale
import java.time.Instant
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import java.util.Locale
import kotlin.math.ceil
import kotlin.math.roundToLong

data class PerformancePoint(val label: String, val actualXaf: Long, val previousXaf: Long, val deltaXaf: Long, val deltaPercent: Double?)
data class PeriodProjection(
    val label: String, val actualXaf: Long, val projectedXaf: Long, val targetXaf: Long?,
    val comparablePreviousXaf: Long, val targetGapXaf: Long?, val achievementPercent: Double?, val remainingDays: Int
)
data class RecoveryAction(val title: String, val detail: String, val priority: String)
data class PerformanceDashboard(
    val day: PeriodProjection, val month: PeriodProjection, val year: PeriodProjection,
    val dailyTrend: List<PerformancePoint>, val monthlyTrend: List<PerformancePoint>, val yearlyTrend: List<PerformancePoint>,
    val revenueXaf: Long, val costedRevenueXaf: Long, val costOfGoodsXaf: Long,
    val grossProfitXaf: Long, val grossMarginPercent: Double?,
    val operatingExpensesXaf: Long, val operatingProfitProxyXaf: Long?, val supplierPayablesXaf: Long,
    val currentMonthSupplierStockPurchasesXaf: Long, val currentMonthSupplierOperatingPurchasesXaf: Long,
    val currentMonthSupplierFixedAssetsXaf: Long, val currentMonthSupplierPaymentsXaf: Long,
    val uncostedStockSalesCount: Int, val lowStockCount: Int, val recoveryActions: List<RecoveryAction>, val dataCoverageDays: Int
)

/** Forecast and recovery rules are local, deterministic, explainable, and based on confirmed sales only. */
object NaxaPerformanceEngine {
    fun analyze(
        sales: List<LocalSale>, accountingEntries: List<LocalAccountingEntry>,
        objectives: List<LocalManagementRecord>, supplierPayablesXaf: Long, lowStockCount: Int,
        nowMillis: Long, zone: ZoneId = ZoneId.of("Africa/Douala")
    ): PerformanceDashboard {
        val today = Instant.ofEpochMilli(nowMillis).atZone(zone).toLocalDate()
        val confirmed = sales.filter { it.status == "confirmed" && it.totalXaf > 0L }
        val byDay = confirmed.groupBy { dateOf(it.createdAtMillis, zone) }.mapValues { it.value.sumOf(LocalSale::totalXaf) }
        val revenue = confirmed.sumOf { it.totalXaf }
        val uncosted = confirmed.count { !it.costSnapshotComplete }
        val costedSales = confirmed.filter { it.costSnapshotComplete }
        val costedRevenue = costedSales.sumOf { it.totalXaf }
        val cogs = costedSales.sumOf { it.costOfGoodsXaf.coerceAtLeast(0L) }
        val gross = costedRevenue - cogs
        val opex = accountingEntries.filter { it.debitAccount.startsWith("OPERATING_EXPENSE") }.sumOf { it.amountXaf }
        // Supplier flows are separated so stock receipts and asset acquisitions are not mistaken for
        // operating expenses, while supplier settlements are not expensed a second time.
        val currentMonthEntries = accountingEntries.filter {
            dateOf(it.occurredAtMillis, zone).let { date ->
                date.year == today.year && date.monthValue == today.monthValue && !date.isAfter(today)
            }
        }
        val supplierStockPurchases = currentMonthEntries.filter {
            it.sourceType == "purchase_receipt" && it.debitAccount == "INVENTORY_ASSET"
        }.sumOf { it.amountXaf }
        val supplierOperatingPurchases = currentMonthEntries.filter {
            it.sourceType == "purchase_receipt" && it.debitAccount.startsWith("OPERATING_EXPENSE")
        }.sumOf { it.amountXaf }
        val supplierFixedAssets = currentMonthEntries.filter {
            it.sourceType == "purchase_receipt" && it.debitAccount == "FIXED_ASSET"
        }.sumOf { it.amountXaf }
        val supplierPayments = currentMonthEntries.filter {
            it.sourceType == "supplier_payment" && it.eventCode == "payable_settlement" &&
                it.debitAccount == "SUPPLIER_PAYABLE"
        }.sumOf { it.amountXaf }
        val margin = if (costedRevenue > 0L) gross.toDouble() * 100.0 / costedRevenue else null
        val operatingProfit = if (uncosted == 0) gross - opex else null
        val avg14 = avgDaily(byDay, today.minusDays(14), today.minusDays(1))
        val avg28 = avgDaily(byDay, today.minusDays(28), today.minusDays(1))
        val avg90 = avgDaily(byDay, today.minusDays(90), today.minusDays(1))
        val elapsed = ((nowMillis - today.atStartOfDay(zone).toInstant().toEpochMilli()).toDouble() / 86_400_000.0).coerceIn(0.05, 1.0)
        val todayActual = byDay[today] ?: 0L
        val pace = (todayActual / elapsed).roundToLong()
        val baselineDay = todayActual + (avg14 * (1.0 - elapsed)).roundToLong()
        val dayForecast = if (elapsed >= 0.95) todayActual else (pace * 0.65 + baselineDay * 0.35).roundToLong().coerceAtLeast(todayActual)
        val dayTarget = targetFor(objectives, "daily", today, zone)
        val day = projection(today.toString(), todayActual, dayForecast, dayTarget,
            byDay[today.minusDays(7)] ?: byDay[today.minusDays(1)] ?: 0L, if (elapsed >= 0.95) 0 else 1)

        val monthKey = YearMonth.from(today)
        val monthActual = sum(byDay, monthKey.atDay(1), today)
        val monthEnd = monthKey.atEndOfMonth()
        val remainMonth = ChronoUnit.DAYS.between(today, monthEnd).toInt().coerceAtLeast(0)
        val previousMonth = monthKey.minusMonths(1)
        val previousMonthComparable = sum(byDay, previousMonth.atDay(1), previousMonth.atDay(today.dayOfMonth.coerceAtMost(previousMonth.lengthOfMonth())))
        val monthTarget = targetFor(objectives, "monthly", today, zone)
        val monthForecast = monthActual + avg28 * remainMonth
        val month = projection(monthKey.toString(), monthActual, monthForecast, monthTarget, previousMonthComparable, remainMonth)

        val yearEnd = LocalDate.of(today.year, 12, 31)
        val yearActual = sum(byDay, LocalDate.of(today.year, 1, 1), today)
        val previousYearDate = today.minusYears(1)
        val previousYearComparable = sum(byDay, LocalDate.of(today.year - 1, 1, 1), previousYearDate)
        val remainYear = ChronoUnit.DAYS.between(today, yearEnd).toInt().coerceAtLeast(0)
        val yearTarget = targetFor(objectives, "annual", today, zone) ?: targetFor(objectives, "yearly", today, zone)
        val yearForecast = yearActual + avg90 * remainYear
        val year = projection(today.year.toString(), yearActual, yearForecast, yearTarget, previousYearComparable, remainYear)

        val daily = (13L downTo 0L).map { n ->
            val d = today.minusDays(n)
            point(d.toString(), byDay[d] ?: 0L, byDay[d.minusDays(1)] ?: 0L)
        }
        val monthly = (11L downTo 0L).map { n ->
            val p = monthKey.minusMonths(n)
            val currentEnd = if (p == monthKey) today else p.atEndOfMonth()
            val previousComparable = if (p == monthKey) previousMonthComparable
                else sum(byDay, p.minusMonths(1).atDay(1), p.minusMonths(1).atEndOfMonth())
            point(p.toString(), sum(byDay, p.atDay(1), currentEnd), previousComparable)
        }
        val yearly = (4 downTo 0).map { n ->
            val y = today.year - n
            val end = if (y == today.year) today else LocalDate.of(y, 12, 31)
            point(y.toString(), sum(byDay, LocalDate.of(y, 1, 1), end),
                if (y == today.year) previousYearComparable
                else sum(byDay, LocalDate.of(y - 1, 1, 1), LocalDate.of(y - 1, 12, 31)))
        }

        val recent = confirmed.filter { !dateOf(it.createdAtMillis, zone).isBefore(today.minusDays(30)) }
        val averageTicket = if (recent.isEmpty()) 0.0 else recent.sumOf { it.totalXaf }.toDouble() / recent.size
        val actions = mutableListOf<RecoveryAction>()
        listOf(day, month, year).forEach { period ->
            val gap = (period.targetGapXaf ?: 0L).coerceAtLeast(0L)
            if (period.targetXaf != null && gap > 0L) {
                val remainingDays = period.remainingDays.coerceAtLeast(1)
                val extraPerDay = ceil(gap.toDouble() / remainingDays).toLong()
                val ticketCount = if (averageTicket > 0.0) ceil(extraPerDay / averageTicket).toInt() else null
                val volume = ticketCount?.let { " Au ticket moyen des 30 derniers jours, cela demande environ " + it + " vente(s) additionnelle(s) par jour." }
                    ?: " Le volume de ventes additionnel sera calculable avec un historique suffisant."
                actions += RecoveryAction(
                    "Redressement de l'objectif " + period.label,
                    "La projection est inférieure à la cible de " + xaf(gap) + ". Effort moyen restant : " + xaf(extraPerDay) + " par jour sur " + period.remainingDays + " jour(s)." + volume,
                    if (period == day) "high" else "high"
                )
            }
        }
        val previous14Avg = avgDaily(byDay, today.minusDays(28), today.minusDays(15))
        if (previous14Avg > 0L && avg14 < previous14Avg * 0.9) {
            actions += RecoveryAction("Réactiver le rythme commercial",
                "La moyenne des 14 derniers jours recule d'au moins 10 % par rapport aux 14 jours précédents. Relancer les devis ouverts, recontacter les clients inactifs et planifier des offres ciblées.", "high")
        }
        val priorMonthRevenue = previousMonthComparable
        val previousComparableMonthEnd = previousMonth.atDay(today.dayOfMonth.coerceAtMost(previousMonth.lengthOfMonth()))
        val currentMonthCosts = accountingEntries.filter {
            dateOf(it.occurredAtMillis, zone).let { d -> d.year == today.year && d.monthValue == today.monthValue && !d.isAfter(today) } &&
                it.debitAccount == "COST_OF_GOODS_SOLD"
        }.sumOf { it.amountXaf }
        val priorMonthCosts = accountingEntries.filter {
            dateOf(it.occurredAtMillis, zone).let { d -> d.year == previousMonth.year && d.monthValue == previousMonth.monthValue && !d.isAfter(previousComparableMonthEnd) } &&
                it.debitAccount == "COST_OF_GOODS_SOLD"
        }.sumOf { it.amountXaf }
        val uncostedCurrentMonth = confirmed.count {
            dateOf(it.createdAtMillis, zone).let { d -> d.year == today.year && d.monthValue == today.monthValue } &&
                it.inventoryItemId != null && it.stockQuantity != null && !it.costSnapshotComplete
        }
        val uncostedPriorMonth = confirmed.count {
            dateOf(it.createdAtMillis, zone).let { d -> d.year == previousMonth.year && d.monthValue == previousMonth.monthValue } &&
                it.inventoryItemId != null && it.stockQuantity != null && !it.costSnapshotComplete
        }
        val currentRate = if (monthActual > 0 && uncostedCurrentMonth == 0) (monthActual - currentMonthCosts).toDouble() / monthActual else null
        val priorRate = if (priorMonthRevenue > 0 && uncostedPriorMonth == 0) (priorMonthRevenue - priorMonthCosts).toDouble() / priorMonthRevenue else null
        if (currentRate != null && priorRate != null && currentRate < priorRate - 0.03) {
            actions += RecoveryAction("Protéger la marge commerciale",
                "Le taux de marge brute recule par rapport au mois précédent. Réexaminer les coûts d'achat, les remises et les prix des articles les plus vendus avant de chercher uniquement du volume.", "high")
        }
        if (lowStockCount > 0) actions += RecoveryAction("Prévenir les ruptures",
            lowStockCount.toString() + " article(s) sont au seuil de réapprovisionnement ou en dessous. Prioriser les produits qui contribuent au chiffre d'affaires et confirmer prix et délais fournisseurs.", "medium")
        if (supplierPayablesXaf > 0L) actions += RecoveryAction("Maîtriser les dettes fournisseurs",
            "Les dettes fournisseurs ouvertes atteignent " + xaf(supplierPayablesXaf) + ". Rapprocher les factures et échéances puis planifier les règlements selon la trésorerie disponible.", "medium")
        if (actions.isEmpty()) actions += RecoveryAction("Maintenir le pilotage",
            "Aucun écart prioritaire n'est détecté dans les données locales disponibles. Continuer le suivi des ventes confirmées, des marges, des objectifs et des échéances fournisseurs.", "low")
        val firstDate = confirmed.minOfOrNull { dateOf(it.createdAtMillis, zone) }
        val coverage = firstDate?.let { ChronoUnit.DAYS.between(it, today).toInt() + 1 } ?: 0
        return PerformanceDashboard(day, month, year, daily, monthly, yearly, revenue, costedRevenue, cogs, gross, margin, opex,
            operatingProfit, supplierPayablesXaf, supplierStockPurchases, supplierOperatingPurchases,
            supplierFixedAssets, supplierPayments, uncosted, lowStockCount, actions.take(8), coverage)
    }

    private fun projection(label: String, actual: Long, forecast: Long, target: Long?, previous: Long, remaining: Int) =
        PeriodProjection(label, actual, forecast, target, previous, target?.minus(forecast),
            target?.takeIf { it > 0 }?.let { forecast.toDouble() * 100.0 / it }, remaining)

    private fun targetFor(rows: List<LocalManagementRecord>, period: String, date: LocalDate, zone: ZoneId): Long? {
        val latestPerSite = rows.asSequence()
            .filter { it.recordType == "business_goal" && it.counterparty.equals(period, true) && it.amountXaf > 0L }
            .filter {
                val created = dateOf(it.createdAtMillis, zone)
                when (period) {
                    "daily" -> created == date
                    "monthly" -> created.year == date.year && created.monthValue == date.monthValue
                    "annual", "yearly" -> created.year == date.year
                    else -> false
                }
            }
            .groupBy { it.siteId }
            .values
            .mapNotNull { siteRecords -> siteRecords.maxByOrNull { it.createdAtMillis }?.amountXaf }
        return latestPerSite.takeIf { it.isNotEmpty() }?.sum()
    }

    private fun dateOf(millis: Long, zone: ZoneId) = Instant.ofEpochMilli(millis).atZone(zone).toLocalDate()
    private fun sum(values: Map<LocalDate, Long>, from: LocalDate, to: LocalDate): Long =
        if (to.isBefore(from)) 0L else values.filterKeys { !it.isBefore(from) && !it.isAfter(to) }.values.sum()
    private fun avgDaily(values: Map<LocalDate, Long>, from: LocalDate, to: LocalDate): Long {
        if (to.isBefore(from)) return 0L
        val count = ChronoUnit.DAYS.between(from, to).toInt() + 1
        return (sum(values, from, to).toDouble() / count).roundToLong()
    }
    private fun point(label: String, actual: Long, previous: Long) =
        PerformancePoint(label, actual, previous, actual - previous,
            if (previous > 0L) (actual - previous).toDouble() * 100.0 / previous else null)
    private fun xaf(value: Long) = String.format(Locale.FRANCE, "%,d FCFA", value).replace(',', ' ')
}
