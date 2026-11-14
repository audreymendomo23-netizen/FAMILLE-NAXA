package cm.naxa.core.ai

import kotlin.math.abs
import kotlin.math.sqrt

data class Insight(val code: String, val score: Double, val reason: String)

object LocalInsights {
    fun movingAverage(values: List<Double>, window: Int): Double? {
        require(window > 0)
        if (values.size < window) return null
        return values.takeLast(window).average()
    }

    /** Population z-score; returns null with too little or constant data. */
    fun anomalyScore(values: List<Double>, candidate: Double): Double? {
        if (values.size < 3) return null
        val mean = values.average()
        val variance = values.sumOf { (it - mean) * (it - mean) } / values.size
        if (variance == 0.0) return if (candidate == mean) 0.0 else null
        return abs(candidate - mean) / sqrt(variance)
    }

    fun depletionDays(currentStock: Double, dailyConsumption: List<Double>): Double? {
        require(currentStock >= 0)
        val avg = movingAverage(dailyConsumption, minOf(7, dailyConsumption.size))
            ?: return null
        if (avg <= 0) return null
        return currentStock / avg
    }

    fun explain(code: String, score: Double, evidence: String): Insight =
        Insight(code, score, evidence)
}
