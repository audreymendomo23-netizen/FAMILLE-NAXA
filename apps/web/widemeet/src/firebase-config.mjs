// Public Firebase Web SDK identifiers supplied by the project owner. Never put service account keys here.
export const publicFirebaseConfig=Object.freeze({
 apiKey:"AIzaSyDCuYEhpsIP_9r8PWTb1OWo5fAPSk8UEDs",
 authDomain:"naxameet.firebaseapp.com",
 projectId:"naxameet",
 storageBucket:"naxameet.firebasestorage.app",
 messagingSenderId:"404923635551",
 appId:"1:404923635551:web:bc810df38bc0f991ab88ea"
});
export function resolveFirebasePush(env={}){
 const config={...publicFirebaseConfig,apiKey:env.VITE_WIDEMEET_FIREBASE_API_KEY??publicFirebaseConfig.apiKey,appId:env.VITE_WIDEMEET_FIREBASE_APP_ID??publicFirebaseConfig.appId,projectId:env.VITE_WIDEMEET_FIREBASE_PROJECT_ID??publicFirebaseConfig.projectId,messagingSenderId:env.VITE_WIDEMEET_FIREBASE_SENDER_ID??publicFirebaseConfig.messagingSenderId};
 const vapid=env.VITE_WIDEMEET_FIREBASE_VAPID_KEY;
 const configured=env.VITE_WIDEMEET_PUSH_ENABLED==="true"&&typeof config.apiKey==="string"&&config.apiKey.trim().length>0&&config.projectId===publicFirebaseConfig.projectId&&config.messagingSenderId===publicFirebaseConfig.messagingSenderId&&config.appId===publicFirebaseConfig.appId&&typeof vapid==="string"&&/^B[A-Za-z0-9_-]{86}$/.test(vapid);
 return {config,vapid,configured};
}
