import {run} from './worker.mjs';
Deno.serve(req=>run(req,{url:Deno.env.get('SUPABASE_URL'),service:Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'),jobSecret:Deno.env.get('GRILLAD_PUSH_JOB_SECRET'),account:Deno.env.get('GRILLAD_FCM_SERVICE_ACCOUNT_JSON')}));
