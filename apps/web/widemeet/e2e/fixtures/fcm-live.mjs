import {getFirebasePushToken} from "../../src/PushPreferences.tsx";
let state=null;const received=new Set();
window.qualification={
 async open(){
  if(Notification.permission!=="granted")throw Error("notification permission");
  await navigator.serviceWorker.register("/sw.js");
  const {m,messaging,token}=await getFirebasePushToken();
  const off=m.onMessage(messaging,p=>{if(p.data?.app_id==="WIDEMEET"&&p.data?.notification_id)received.add(p.data.notification_id)});
  state={m,messaging,off};return token;
 },
 has(id){return received.has(id)},
 async background(id){const reg=await navigator.serviceWorker.ready;return (await reg.getNotifications({tag:id})).some(n=>n.tag===id&&n.title==="WideMeet")},
 async close(){if(state){const old=state;state=null;old.off();await old.m.deleteToken(old.messaging)}const reg=await navigator.serviceWorker.ready;for(const n of await reg.getNotifications())n.close()}
};
