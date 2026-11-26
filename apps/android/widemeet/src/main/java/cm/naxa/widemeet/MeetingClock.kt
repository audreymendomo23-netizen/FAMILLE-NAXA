package cm.naxa.widemeet

/** Read-only countdown from the authoritative deadline. Never extends a session locally. */
data class MeetingClockView(val seconds: Long, val warning: Boolean, val expired: Boolean, val canExtend: Boolean)
fun meetingClockView(endMs: Long, hardEndMs: Long, nowMs: Long, status: String, organizerAllowed: Boolean): MeetingClockView {
    require(endMs >= 0 && nowMs >= 0 && hardEndMs >= endMs)
    val active = status == "open" || status == "paused"
    val delta = if (active && endMs > nowMs) endMs - nowMs else 0L
    val seconds = delta / 1000 + if (delta % 1000 != 0L) 1 else 0
    return MeetingClockView(seconds, active && organizerAllowed && seconds in 1L..300L, active && seconds == 0L, active && organizerAllowed && seconds > 0 && endMs < hardEndMs)
}
