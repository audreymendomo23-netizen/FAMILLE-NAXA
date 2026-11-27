// Public client metadata only. Never accept a service account or FCM server key.
export function extractFirebaseAndroidConfig(input){
 if(input?.type==='service_account'||input?.private_key)throw Error('PRIVATE_FIREBASE_CONFIG');
 const project=input?.project_info?.project_id,sender=input?.project_info?.project_number;
 if(typeof project!=='string'||!/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(project)||project==='naxatechnologie')throw Error('DEDICATED_PROJECT_REQUIRED');
 if(typeof sender!=='string'||!/^\d+$/.test(sender))throw Error('INVALID_SENDER');
 const clients=(Array.isArray(input.client)?input.client:[]).filter(c=>c?.client_info?.android_client_info?.package_name==='cm.naxa.grillad');
 if(clients.length!==1)throw Error('GRILLAD_CLIENT_REQUIRED');
 const appId=clients[0].client_info.mobilesdk_app_id,key=clients[0].api_key?.[0]?.current_key;
 if(typeof appId!=='string'||!appId.startsWith('1:'+sender+':android:')||!/^[a-zA-Z0-9]+$/.test(appId.split(':')[3]??'')||appId.split(':').length!==4)throw Error('APP_ID_MISMATCH');
 if(typeof key!=='string'||!/^AIza[A-Za-z0-9_-]{20,}$/.test(key))throw Error('INVALID_CLIENT_KEY');
 return {projectId:project,senderId:sender,appId,apiKey:key};
}
