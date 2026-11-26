import { test } from "node:test";
import assert from "node:assert/strict";
import { extractFirebaseAndroidConfig } from "./firebase-android-config.mjs";
const fixture={project_info:{project_id:"naxa-services-qa",project_number:"123456"},client:[{client_info:{mobilesdk_app_id:"1:123456:android:abc123",android_client_info:{package_name:"cm.naxa.naxaservices"}},api_key:[{current_key:"AIza"+"x".repeat(35)}]}]};
test("accept only registered NAXA SERVICES package and consistent public config",()=>{
  assert.equal(extractFirebaseAndroidConfig(fixture).NAXA_SERVICES_FIREBASE_PROJECT_ID,"naxa-services-qa");
  assert.equal(extractFirebaseAndroidConfig(fixture).NAXA_SERVICES_FIREBASE_APP_ID,"1:123456:android:abc123");
  for(const bad of [{...fixture,project_info:{...fixture.project_info,project_id:"naxatechnologie"}},{...fixture,client:[]},{...fixture,client:[...fixture.client,...fixture.client]},{...fixture,project_info:{...fixture.project_info,project_number:"789"}},{...fixture,client:[{...fixture.client[0],api_key:[{current_key:"private-key"}]}]}]) assert.throws(()=>extractFirebaseAndroidConfig(bad));
});
