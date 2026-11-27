import {handle} from './handler.mjs';
Deno.serve(req=>handle(req,{url:Deno.env.get('SUPABASE_URL')??'',key:Deno.env.get('SUPABASE_ANON_KEY')??'',service:Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')??'',origins:(Deno.env.get('GRILLAD_ALLOWED_ORIGINS')??'').split(',').map(x=>x.trim()).filter(Boolean)}));
