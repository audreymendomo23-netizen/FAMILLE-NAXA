import {cleanup} from "./contract.ts";
if(import.meta.main)Deno.serve(req=>cleanup(req,{
 url:Deno.env.get("SUPABASE_URL")??"",key:Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")??"",
 secret:Deno.env.get("NS_ATTENDANCE_CLEANUP_SECRET")??"",enabled:Deno.env.get("NS_ATTENDANCE_CLEANUP_QUALIFIED")==="true"
}));
