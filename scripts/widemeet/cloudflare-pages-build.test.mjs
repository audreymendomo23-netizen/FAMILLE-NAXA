import test from "node:test";import assert from "node:assert/strict";import {validate} from "./cloudflare-pages-build.mjs";
const env={VITE_WIDEMEET_PAGES_PROXY:"true",VITE_WIDEMEET_PUSH_ENABLED:"true"};
test("preview proxy configuration accepted",()=>assert.doesNotThrow(()=>validate(env)));
test("wrong endpoint or disabled proxy rejected",()=>{assert.throws(()=>validate({}));assert.throws(()=>validate({...env,VITE_WIDEMEET_AUTH_URL:"https://example.com"}))});
test("private frontend values rejected",()=>{assert.throws(()=>validate({...env,VITE_SERVICE_ROLE:"secret"}));assert.throws(()=>validate({...env,VITE_KEY:"sb_secret_fake"}));const payload=Buffer.from(JSON.stringify({role:"service_role"})).toString("base64url");assert.throws(()=>validate({...env,VITE_KEY:"aaa."+payload+".bbb"}))});
