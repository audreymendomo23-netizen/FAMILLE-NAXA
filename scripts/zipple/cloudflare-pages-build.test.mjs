import test from "node:test";
import assert from "node:assert/strict";
import {validate,endpoint} from "./cloudflare-pages-build.mjs";
const valid={VITE_ZIPPLE_API_URL:endpoint};
test("only ZIPPLE endpoint is accepted",()=>{assert.doesNotThrow(()=>validate(valid));for(const url of ["","http://localhost:54321","https://idupfjbkwjcavyisxteo.supabase.co/functions/v1/naxa-services-auth",endpoint+"/","https://example.com"])assert.throws(()=>validate({VITE_ZIPPLE_API_URL:url}));});
test("no private client configuration",()=>{for(const env of [{VITE_SERVICE_ROLE_KEY:"example"},{VITE_ZIPPLE_PASSWORD:"example"},{VITE_OTHER:"sb_secret_example"},{VITE_OTHER:"e30."+Buffer.from(JSON.stringify({role:"service_role"})).toString("base64url")+".sig"}])assert.throws(()=>validate({...valid,...env}));});
