import test from 'node:test';import assert from 'node:assert/strict';
import {validate} from './cloudflare-pages-build.mjs';
import {extractFirebaseAndroidConfig as extract} from './firebase-android-config.mjs';
test('preview without backend; release must have dedicated endpoint',()=>{validate({});assert.throws(()=>validate({GRILLAD_RELEASE:'1'}));validate({GRILLAD_RELEASE:'1',VITE_GRILLAD_API_URL:'https://example.supabase.co/functions/v1/grillad'});});
test('reject other applications and private keys',()=>{assert.throws(()=>validate({VITE_GRILLAD_API_URL:'https://example.supabase.co/functions/v1/zipple-n1'}));assert.throws(()=>validate({VITE_SERVICE_ROLE:'fake'}));assert.throws(()=>validate({VITE_PUBLIC_KEY:'sb_secret_example'}));});
const config=()=>({project_info:{project_id:'grillad-test',project_number:'1234'},client:[{client_info:{mobilesdk_app_id:'1:1234:android:abc',android_client_info:{package_name:'cm.naxa.grillad'}},api_key:[{current_key:'AIza'+'x'.repeat(25)}]}]});
test('accept public client of GRILLAD only',()=>{assert.equal(extract(config()).senderId,'1234');const c=config();c.client[0].client_info.android_client_info.package_name='cm.naxa.zipple';assert.throws(()=>extract(c));});
test('reject private account and mismatched sender',()=>{assert.throws(()=>extract({type:'service_account',private_key:'fake'}));const c=config();c.project_info.project_number='456';assert.throws(()=>extract(c));});
