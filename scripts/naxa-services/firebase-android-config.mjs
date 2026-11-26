// Import only public Firebase Android config. Never provide a service-account JSON file.
export function extractFirebaseAndroidConfig(input) {
  const project = input?.project_info?.project_id;
  const sender = input?.project_info?.project_number;
  if (typeof project !== "string" || !/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(project) || project === "naxatechnologie") throw new Error("Dedicated Firebase project required");
  if (typeof sender !== "string" || !/^\d+$/.test(sender)) throw new Error("Invalid Firebase project number");
  const clients = Array.isArray(input.client) ? input.client.filter(c=>c?.client_info?.android_client_info?.package_name==="cm.naxa.naxaservices") : [];
  if (clients.length !== 1) throw new Error("Exactly one cm.naxa.naxaservices Android client required");
  const client = clients[0];
  const appId = client.client_info.mobilesdk_app_id;
  const key = client.api_key?.[0]?.current_key;
  if (typeof appId !== "string" || !appId.startsWith("1:"+sender+":android:") || !/^[A-Za-z0-9]+$/.test(appId.split(":")[3]??"") || appId.split(":").length!==4) throw new Error("Firebase app ID and project number mismatch");
  if (typeof key !== "string" || !/^AIza[A-Za-z0-9_-]{20,}$/.test(key)) throw new Error("Invalid Firebase client API key");
  return {NAXA_SERVICES_FIREBASE_PROJECT_ID:project,NAXA_SERVICES_FIREBASE_SENDER_ID:sender,NAXA_SERVICES_FIREBASE_APP_ID:appId,NAXA_SERVICES_FIREBASE_API_KEY:key};
}
