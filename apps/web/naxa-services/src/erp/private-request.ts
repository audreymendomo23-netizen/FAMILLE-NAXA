/** Bind token acquisition, fetch and decoding to the same component/session lifecycle.
 * Aborting a request does not undo an already committed server mutation; retries
 * must retain the existing idempotency identifiers and reconcile server state.
 */
export function assertPrivateRequestCurrent(signal:AbortSignal|undefined,isCurrent:()=>boolean):void{
 if(!signal||signal.aborted||!isCurrent())throw Error("SESSION_CHANGED");
}
export async function privateRequest<T>(signal:AbortSignal|undefined,isCurrent:()=>boolean,getToken:()=>Promise<string>,fetchWithToken:(token:string,signal:AbortSignal)=>Promise<Response>):Promise<T>{
 assertPrivateRequestCurrent(signal,isCurrent);
 const token=await getToken();
 assertPrivateRequestCurrent(signal,isCurrent);
 if(!token)throw Error("SESSION_CHANGED");
 const response=await fetchWithToken(token,signal!);
 assertPrivateRequestCurrent(signal,isCurrent);
 if(!response.ok)throw Error("PRIVATE_REQUEST_FAILED");
 const result=await response.json() as T;
 assertPrivateRequestCurrent(signal,isCurrent);
 return result;
}
