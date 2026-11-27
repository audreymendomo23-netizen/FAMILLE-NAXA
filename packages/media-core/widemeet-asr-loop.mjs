// Sequential per-process consumer; DB SKIP LOCKED + lease fences concurrent replicas.
// No recording content or identifiers in logs; failures back off, shutdown drains one bounded job.
export async function runAsrLoop({worker,signal,wait,report=()=>{},idleMs=5000,maxBackoffMs=60000}){
 if(typeof worker?.runOne!=="function"||!signal||typeof wait!=="function"||!Number.isSafeInteger(idleMs)||idleMs<1||!Number.isSafeInteger(maxBackoffMs)||maxBackoffMs<idleMs)throw Error("invalid ASR loop configuration");
 let delay=idleMs;
 while(!signal.aborted){
  let result;
  try{result=await worker.runOne()}
  catch{result=null}
  if(result?.claimed===true&&result.completed===true){report("completed");delay=idleMs;continue}
  if(result?.claimed===false){report("idle");delay=idleMs}
  else{report("failure");delay=Math.min(maxBackoffMs,delay*2)}
  if(!signal.aborted)await wait(delay,signal);
 }
}
