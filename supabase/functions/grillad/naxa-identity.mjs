// Server-only identity verification. This does not issue a FAMILLE session or grant access.
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export async function verifyNaxaIdentity(token,config,fetcher=fetch){
 const endpoint='https://ykgjfindlgseegmznaog.supabase.co/auth/v1/user';
 if(typeof config?.publishableKey!=='string'||!config.publishableKey)return null;
 if(typeof token!=='string'||token.length>16384||! /^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(token))return null;
 try{
  const response=await fetcher(endpoint,{method:'GET',headers:{apikey:config.publishableKey,Authorization:'Bearer '+token},redirect:'error',cache:'no-store',signal:AbortSignal.timeout(10000)});
  if(!response.ok)return null;
  const user=await response.json();
  if(!UUID.test(user?.id)||user.role!=='authenticated'||user.is_anonymous!==false)return null;
  return {issuer:'https://ykgjfindlgseegmznaog.supabase.co/auth/v1',subject:user.id};
 }catch{return null}
}
