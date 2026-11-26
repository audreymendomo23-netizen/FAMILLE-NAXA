// Hosted entrypoint. Deploy with adapter.mjs and auth-boundary.mjs in the same bundle.
// The adapter import is rewritten from ../auth-boundary.mjs to ./auth-boundary.mjs.
import {createSupabaseZipple} from "./adapter.mjs";
const env=(key:string)=>Deno.env.get(key)??"";
const handler=createSupabaseZipple({url:env("SUPABASE_URL"),anonKey:env("SUPABASE_ANON_KEY"),serviceKey:env("SUPABASE_SERVICE_ROLE_KEY"),origins:env("ZIPPLE_ALLOWED_ORIGINS").split(",").map(s=>s.trim()).filter(Boolean)});
Deno.serve(handler);
