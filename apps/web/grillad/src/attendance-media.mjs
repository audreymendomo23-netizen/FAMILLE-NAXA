// A scope-local monotonic lease: stale asynchronous media responses cannot reopen or submit a cancelled capture.
export function mediaLease(){let generation=0;return {begin:()=>++generation, invalidate:()=>{generation++}, current:ticket=>ticket===generation}}
export function freshGps(timestamp,now=Date.now()){return Number.isFinite(timestamp)&&Number.isFinite(now)&&timestamp<=now+1000&&now-timestamp<=15000}
