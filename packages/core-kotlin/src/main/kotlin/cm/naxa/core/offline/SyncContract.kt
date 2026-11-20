package cm.naxa.core.offline

import java.time.Duration
import java.time.Instant
import java.util.UUID

enum class ConflictPolicy { APPEND_ONLY_REVIEW, SERVER_VERSION_WINS, SET_UNION }

enum class QueueState { PENDING, IN_FLIGHT, ACKNOWLEDGED, NEEDS_REVIEW, FAILED }

data class SyncOperation(
    val operationId: UUID,
    val appId: String,
    val aggregateType: String,
    val aggregateId: String,
    val aggregateVersion: Long?,
    val createdAtDevice: Instant,
    val payload: ByteArray,
    val state: QueueState = QueueState.PENDING
) {
    init {
        require(appId.isNotBlank() && aggregateType.isNotBlank() && aggregateId.isNotBlank())
        require(aggregateVersion == null || aggregateVersion >= 0)
    }
}

data class ServerClockCheckpoint(val serverTime: Instant, val deviceTimeAtSync: Instant)

data class OfflineAllowance(val maxAge: Duration) {
    init { require(!maxAge.isNegative && !maxAge.isZero) }
    companion object {
        val ESSENTIEL_PRO = OfflineAllowance(Duration.ofDays(7))
        val RESEAU = OfflineAllowance(Duration.ofDays(14))
    }
}

sealed interface ClockAssessment {
    data object FirstSyncRequired : ClockAssessment
    data object ClockMovedBackwards : ClockAssessment
    data object WithinAllowance : ClockAssessment
    data object AllowanceExpired : ClockAssessment
}

object SyncContract {
    /**
     * Device timestamps are diagnostic only. The server decides ordering and
     * conflict resolution. Never discard locally queued data on expiry.
     */
    fun assessClock(
        checkpoint: ServerClockCheckpoint?,
        deviceNow: Instant,
        allowance: OfflineAllowance
    ): ClockAssessment {
        if (checkpoint == null) return ClockAssessment.FirstSyncRequired
        if (deviceNow.isBefore(checkpoint.deviceTimeAtSync.minusSeconds(120))) {
            return ClockAssessment.ClockMovedBackwards
        }
        val estimatedServerNow = checkpoint.serverTime.plus(
            Duration.between(checkpoint.deviceTimeAtSync, deviceNow)
        )
        return if (Duration.between(checkpoint.serverTime, estimatedServerNow) <= allowance.maxAge)
            ClockAssessment.WithinAllowance else ClockAssessment.AllowanceExpired
    }

    fun resolveConflict(policy: ConflictPolicy, hasServerVersion: Boolean): QueueState =
        when (policy) {
            ConflictPolicy.APPEND_ONLY_REVIEW -> QueueState.NEEDS_REVIEW
            ConflictPolicy.SERVER_VERSION_WINS ->
                if (hasServerVersion) QueueState.ACKNOWLEDGED else QueueState.NEEDS_REVIEW
            ConflictPolicy.SET_UNION -> QueueState.PENDING
        }
}
