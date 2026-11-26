export function remainingSeconds(endMs, nowMs) {
  if (!Number.isSafeInteger(endMs) || !Number.isSafeInteger(nowMs) || endMs < 0 || nowMs < 0) throw new RangeError("invalid_clock");
  return Math.max(0, Math.ceil((endMs - nowMs) / 1000));
}

export function timerView(meeting, nowMs, actor) {
  const active = ["open","paused"].includes(meeting.status);
  const seconds = active ? remainingSeconds(meeting.endMs,nowMs) : 0;
  const organizer = actor?.enabled === true && actor.orgId === meeting.orgId && actor.memberId === meeting.organizerId;
  return {seconds, warning:active && organizer && seconds>0 && seconds<=300, expired:active && seconds===0, canExtend:active && organizer && seconds>0 && meeting.endMs<meeting.hardEndMs};
}

export function extendMeeting(meeting, command, actor, serverNowMs, priorReceipt=null) {
  // All identities, limits, time and receipts must be loaded by the trusted server under one transaction.
  if(actor?.enabled!==true || actor.orgId!==meeting.orgId || actor.memberId!==meeting.organizerId || command.meetingId!==meeting.id) throw new Error("forbidden");
  if(typeof command.requestId!=="string" || !/^[A-Za-z0-9_-]{16,128}$/.test(command.requestId) || !Number.isSafeInteger(command.expectedRevision) || command.expectedRevision<1 || !Number.isSafeInteger(command.minutes) || command.minutes<1 || command.minutes>480) throw new Error("invalid_request");
  if(![meeting.startMs,meeting.endMs,meeting.hardEndMs,meeting.revision,serverNowMs].every(Number.isSafeInteger) || meeting.startMs<0 || meeting.endMs<=meeting.startMs || meeting.hardEndMs<meeting.endMs || meeting.revision<1 || serverNowMs<meeting.startMs) throw new Error("invalid_state");
  if(priorReceipt!==null){
    if(priorReceipt.requestId!==command.requestId || priorReceipt.meetingId!==meeting.id || priorReceipt.actorId!==actor.memberId || priorReceipt.minutes!==command.minutes || priorReceipt.expectedRevision!==command.expectedRevision) throw new Error("idempotency_conflict");
    return {meeting,receipt:priorReceipt,replayed:true,event:null};
  }
  if(!["open","paused"].includes(meeting.status) || serverNowMs>=meeting.endMs) throw new Error("not_active");
  if(command.expectedRevision!==meeting.revision) throw new Error("revision_conflict");
  const endMs=meeting.endMs+command.minutes*60000;
  if(!Number.isSafeInteger(endMs) || !Number.isSafeInteger(meeting.revision+1) || endMs>meeting.hardEndMs) throw new Error("limit_exceeded");
  const receipt={requestId:command.requestId,meetingId:meeting.id,actorId:actor.memberId,minutes:command.minutes,expectedRevision:command.expectedRevision,revision:meeting.revision+1,previousEndMs:meeting.endMs,endMs};
  return {meeting:{...meeting,endMs,revision:receipt.revision},receipt,replayed:false,event:{type:"meeting_extended",meetingId:meeting.id,orgId:meeting.orgId,requestId:command.requestId,previousEndMs:meeting.endMs,endMs,revision:receipt.revision,actorId:actor.memberId,atMs:serverNowMs}};
}

/** Initial deadline from the actual authorized start, not the scheduled date. */
export function initialDeadline(startMs, durationMinutes, hardEndMs) {
  if (!Number.isSafeInteger(startMs) || startMs < 0 || !Number.isSafeInteger(hardEndMs) || hardEndMs < startMs) throw new RangeError("invalid_clock");
  if (!Number.isSafeInteger(durationMinutes) || durationMinutes < 5 || durationMinutes > 480) throw new RangeError("invalid_duration");
  const endMs = startMs + durationMinutes * 60000;
  if (!Number.isSafeInteger(endMs) || endMs > hardEndMs) throw new Error("limit_exceeded");
  return endMs;
}
