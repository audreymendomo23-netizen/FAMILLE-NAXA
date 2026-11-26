package cm.naxa.widemeet
fun main() {
    val end = 3_700_000L
    val max = 10_900_000L
    check(!meetingClockView(end,max,end-300_001,"open",true).warning)
    check(meetingClockView(end,max,end-300_000,"open",true).warning)
    check(meetingClockView(end,max,end-299_999,"open",true).seconds == 300L)
    check(!meetingClockView(end,max,end-300_000,"open",false).warning)
    check(meetingClockView(end,max,end-300_000,"paused",true).canExtend)
    check(meetingClockView(end,max,end,"open",true).expired)
    check(!meetingClockView(end,end,end-300_000,"open",true).canExtend)
    check(!meetingClockView(end,max,end-300_000,"ended",true).warning)
    check(meetingClockView(end+900_000,max,end-300_000,"open",true).seconds == 1200L)
    check(meetingClockView(end+900_000,max,end+600_000,"open",true).warning)
    check(runCatching { meetingClockView(end,end-1,end-1,"open",true) }.isFailure)
    println("WideMeet Kotlin countdown: 11 assertions passed")
}
