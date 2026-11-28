// Dedicated GRILLAD gateway, adapted from the family accounting bearer/RPC pattern.
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const date=/^\d{4}-\d{2}-\d{2}$/;
const actions=new Set(['add_item','prepare','sell','sell_basket','reconcile_mobile','cancel_sale','cancel_basket','open_cash','close_cash','expense','target','change_price','change_cost','set_item_active','adjust_stock','cancel_expense','set_network_mode','set_service_hours','attendance_request','attendance_decide','set_cost_composition','create_site','set_team_assignment','dimension_target','set_site_enabled','missing_departure_request','missing_departure_decide','schedule_service_hours','employee_request','renewal_request','central_request_cancel','cash_recount_request','cash_recount_decide','record_purchase','cancel_purchase','missing_arrival_request','missing_arrival_decide','set_attendance_policy','connect_item_set','connect_link_set']);
export async function handle(request,env,fetcher=fetch){
 const origin=request.headers.get('origin');const allowed=env.origins||[];
 const headers={'Content-Type':'application/json','Cache-Control':'no-store','Vary':'Origin','Access-Control-Allow-Methods':'POST, OPTIONS','Access-Control-Allow-Headers':'authorization, apikey, content-type'};
 if(origin&&allowed.includes(origin))headers['Access-Control-Allow-Origin']=origin;
 const reply=(status,body)=>new Response(JSON.stringify(body),{status,headers});
 if(origin&&!allowed.includes(origin))return reply(403,{error:'ORIGIN_DENIED'});
 if(request.method==='OPTIONS')return new Response(null,{status:204,headers});
 if(request.method!=='POST')return reply(405,{error:'METHOD'});
 const base=(env.url||'').replace(/\/$/,'');if(!/^https?:\/\/[^/]+$/.test(base)||!env.key)return reply(503,{error:'NOT_CONFIGURED'});
 let body;try{const raw=await request.text();if(raw.length>700000)return reply(413,{error:'TOO_LARGE'});body=JSON.parse(raw);if(!body||typeof body!=='object'||Array.isArray(body))throw Error()}catch{return reply(400,{error:'INVALID_BODY'})}
 const bearer=request.headers.get('authorization')||'';
 async function post(path,data,token=env.key){
  const r=await fetcher(base+path,{method:'POST',headers:{apikey:env.key,Authorization:'Bearer '+token,'Content-Type':'application/json'},body:JSON.stringify(data),redirect:'error',signal:AbortSignal.timeout(15000)});
  const result=await r.json().catch(()=>null);
  return {status:r.status,ok:r.ok,result};
 }
 function upstream(x){return x.ok?reply(200,{result:x.result}):reply(x.status===401?401:x.status===403||x.result?.code==='42501'?403:x.status===429?429:x.status>=500?503:400,{error:x.result?.code==='42501'?'ACCESS_DENIED':'OPERATION_REFUSED'});}
 try{
  async function workspaceFor(token){
   const w=await post('/rest/v1/rpc/grillad_workspace',{},token);
   if(!w.ok||!Array.isArray(w.result))return null;
   if(w.result.length)return {sites:w.result,renewal_only:false};
   const b=await post('/rest/v1/rpc/grillad_renewal_workspace',{},token);
   return b.ok&&Array.isArray(b.result)&&b.result.length?{sites:b.result,renewal_only:true}:null;
  }
  if(body.action==='login'||body.action==='recovery'){
   if(!env.service)return reply(503,{error:'AUTH_NOT_CONFIGURED'});
   const phone=String(body.phone||'').replace(/[\s().-]/g,'');
   if(!/^\+[1-9]\d{7,14}$/.test(phone))return reply(400,{error:'INVALID_PHONE'});
   const recovery=body.action==='recovery';
   if(!recovery&&(typeof body.password!=='string'||body.password.length<1||body.password.length>256||!uuid.test(body.installation)||!['web','android'].includes(body.platform)))return reply(400,{error:'INVALID_LOGIN'});
   const hasInvite=!recovery&&(body.request!=null||body.invite!=null);
   if(hasInvite&&(!uuid.test(body.request)||typeof body.invite!=='string'||!/^[A-Za-z0-9_-]{32,128}$/.test(body.invite)))return reply(400,{error:'INVALID_INVITATION'});
   const digest=await crypto.subtle.digest('SHA-256',new TextEncoder().encode('grillad:'+phone));const hash=Array.from(new Uint8Array(digest),x=>x.toString(16).padStart(2,'0')).join('');
   async function control(path,data){const r=await fetcher(base+'/rest/v1/rpc/'+path,{method:'POST',headers:{apikey:env.service,Authorization:'Bearer '+env.service,'Content-Type':'application/json'},body:JSON.stringify(data),redirect:'error',signal:AbortSignal.timeout(15000)});return r.ok&&await r.json()===true}
   const allowed=await control('grillad_auth_begin',{p_hash:hash,p_recovery:recovery});
   if(recovery)return reply(200,{result:{received:true}}); // uniform response; not proof of delivery or account existence
   if(!allowed)return reply(429,{error:'TEMPORARILY_LOCKED'});
   const x=await post('/auth/v1/token?grant_type=password',{phone,password:body.password});
   if(!x.ok)return reply(401,{error:'INVALID_CREDENTIALS'});
   const s=x.result;if(!s?.access_token||!s?.refresh_token||!uuid.test(s.user?.id)||s.user?.app_metadata?.must_change_password)return reply(403,{error:'ACCOUNT_SETUP_REQUIRED'});
   let sid;try{sid=JSON.parse(atob(s.access_token.split('.')[1].replace(/-/g,'+').replace(/_/g,'/'))).session_id}catch{return reply(403,{error:'SESSION'})}
   if(hasInvite){const accepted=await post('/rest/v1/rpc/grillad_employee_accept',{p_request:body.request,p_token:body.invite},s.access_token);if(!accepted.ok||accepted.result?.status!=='processed')return reply(403,{error:'INVITATION_DENIED'});}
   if(!uuid.test(sid)||!await control('grillad_auth_finish',{p_hash:hash,p_user:s.user.id,p_session:sid,p_installation:body.installation,p_platform:body.platform}))return reply(403,{error:'DEVICE_OR_GRANT_DENIED'});
   const w=await workspaceFor(s.access_token);if(!w)return reply(403,{error:'NO_WORKSPACE'});
   return reply(200,{result:{user_id:s.user.id,access:s.access_token,refresh:s.refresh_token,...w}});
  }
  if(body.action==='refresh'){
   if(typeof body.refresh!=='string'||body.refresh.length<10||body.refresh.length>8192)return reply(400,{error:'INVALID_REFRESH'});
   const x=await post('/auth/v1/token?grant_type=refresh_token',{refresh_token:body.refresh});
   if(!x.ok)return upstream(x);const s=x.result;
   if(!s?.access_token||!s?.refresh_token)return reply(401,{error:'SESSION'});
   let uid=s.user?.id;try{uid=uid||JSON.parse(atob(s.access_token.split('.')[1].replace(/-/g,'+').replace(/_/g,'/'))).sub}catch{}if(!uuid.test(uid))return reply(401,{error:'SESSION'});
   const w=await workspaceFor(s.access_token);if(!w)return reply(403,{error:'NO_WORKSPACE'});
   return reply(200,{result:{user_id:uid,access:s.access_token,refresh:s.refresh_token,...w}});
  }
  if(['connect_catalog','connect_submit','connect_status','connect_pair'].includes(body.action)){
   if(!env.service||typeof body.qr!=='string'||!/^[A-Za-z0-9_-]{32,128}$/.test(body.qr))return reply(403,{error:'PARTNER_UNAVAILABLE'});
   const bytes=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(body.qr));const hash=Array.from(new Uint8Array(bytes),x=>x.toString(16).padStart(2,'0')).join('');
   let rpc='grillad_connect_catalog',params={p_hash:hash};
   if(body.action==='connect_pair'){if(typeof body.table!=='string'||!/^[0-9a-f]{64}$/.test(body.table))return reply(400,{error:'TABLE_TOKEN'});const raw=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(body.table));rpc='grillad_connect_pair_check';params={...params,p_zipple_hash:Array.from(new Uint8Array(raw),x=>x.toString(16).padStart(2,'0')).join('')}}
   if(body.action==='connect_submit'){if(!uuid.test(body.order)||!Array.isArray(body.lines))return reply(400,{error:'ORDER'});rpc='grillad_connect_submit';params={...params,p_order:body.order,p_lines:body.lines}}
   if(body.action==='connect_status'){if(!uuid.test(body.order))return reply(400,{error:'ORDER'});rpc='grillad_connect_status';params={...params,p_order:body.order}}
   const r=await fetcher(base+'/rest/v1/rpc/'+rpc,{method:'POST',headers:{apikey:env.service,Authorization:'Bearer '+env.service,'Content-Type':'application/json'},body:JSON.stringify(params),redirect:'error',signal:AbortSignal.timeout(15000)});
   return upstream({ok:r.ok,status:r.status,result:await r.json().catch(()=>null)});
  }
  if(!/^Bearer \S+$/.test(bearer))return reply(401,{error:'SESSION'});
  const token=bearer.slice(7);
  if(body.action==='subscription_debit_share'||body.action==='subscription_credit_capture'){
   const level=body.action==='subscription_debit_share'?1:2;
   const auto=level===2&&body.request==null;
   if(level===2){body.device=body.device??body.deviceId;body.sms=body.sms??body.smsText;body.sender=body.sender??body.senderOriginAddress;}
   if(!env.service||(!auto&&!uuid.test(body.request))||typeof body.sms!=='string'||body.sms.length<12||body.sms.length>8000)return reply(400,{error:'CAPTURE_INPUT'});
   if(level===2&&(!uuid.test(body.device)||typeof body.deviceToken!=='string'||!/^[A-Za-z0-9_-]{32,128}$/.test(body.deviceToken)||body.source!=='sms_receiver'||!['MobileMoney','OrangeMoney'].includes(body.sender)))return reply(403,{error:'CAPTURE_DEVICE_REQUIRED'});
   const id=await fetcher(base+'/auth/v1/user',{method:'GET',headers:{apikey:env.key,Authorization:bearer},redirect:'error',signal:AbortSignal.timeout(10000)});const user=id.ok?await id.json():null;let sid;try{sid=JSON.parse(atob(token.split('.')[1].replace(/-/g,'+').replace(/_/g,'/'))).session_id}catch{}if(!uuid.test(user?.id)||!uuid.test(sid))return reply(401,{error:'SESSION'});
   const digest=async v=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(v))),x=>x.toString(16).padStart(2,'0')).join('');
   const {parsePromoteurPaymentSms,normalizePaymentSms}=await import('./naxa-payment-sms.ts');
   const deviceHash=level===2?await digest(body.deviceToken):null;
   if(auto){
    const channel=body.sender==='MobileMoney'?'mtn_momo':'orange_money';
    if(body.canal!==channel)return reply(400,{error:'CAPTURE_CHANNEL'});
    const received=Date.parse(body.smsReceivedAt);if(!Number.isFinite(received)||received>Date.now()+60000||received<Date.now()-86400000)return reply(400,{error:'CAPTURE_TIME'});
    const p=parsePromoteurPaymentSms(body.sms,channel,body.sender);const payer=String(p?.payerNumber??'').replace(/\D/g,'').slice(-9);
    if(!p||p.direction!=='merchant_credit'||!p.success||!Number.isSafeInteger(p.amount)||p.amount<=0||!p.reference||p.reference.length<5||!/^6\d{8}$/.test(payer)||!p.occurredAt||Math.abs(Date.parse(p.occurredAt)-received)>300000)return reply(202,{result:{status:'manual_review',level:3}});
    const found=await post('/rest/v1/rpc/grillad_capture_match',{p_actor:user.id,p_session:sid,p_device:body.device,p_hash:deviceHash,p_channel:channel,p_reference:p.reference,p_amount:p.amount,p_payer:payer,p_occurred:p.occurredAt},env.service);
    if(!found.ok)return upstream(found);if(!uuid.test(found.result))return reply(202,{result:{status:'manual_review',level:3}});
    body.request=found.result;
   }
   const args={p_request:body.request,p_actor:user.id,p_session:sid,p_device:level===2?body.device:null,p_hash:deviceHash,p_level:level};
   const ctx=await post('/rest/v1/rpc/grillad_capture_context',args,env.service);if(!ctx.ok)return upstream(ctx);
const c=ctx.result;const parsed=parsePromoteurPaymentSms(body.sms,c.channel,level===2?body.sender:null);
   if(!parsed||parsed.direction!==(level===1?'payer_debit':'merchant_credit')||!parsed.success||parsed.amount!==c.amount||!parsed.reference||parsed.reference.length<5||(level===2&&body.sender!==(c.channel==='mtn_momo'?'MobileMoney':'OrangeMoney')))return reply(202,{result:{status:'manual_review',level:3}});
   const digits=v=>String(v??'').replace(/\D/g,'');const dest=digits(c.destination);const actual=digits(parsed.merchantNumber);
   const name=v=>normalizePaymentSms(v).replace(/[^a-z0-9]/g,'');
   const destinationOK=actual?dest.length>=9&&actual.slice(-9)===dest.slice(-9):level===1?!!parsed.merchantLabel&&name(parsed.merchantLabel)===name(c.beneficiary):c.channel==='mtn_momo';
   const payer=digits(parsed.payerNumber).slice(-9);
   // Missing or ambiguous values never upgraded by a client field. Manual review remains available.
   if(!destinationOK||!/^6\d{8}$/.test(payer)||!parsed.occurredAt)return reply(202,{result:{status:'manual_review',level:3,reference:parsed.reference,amount:parsed.amount,payer,occurred:parsed.occurredAt}});
   return upstream(await post('/rest/v1/rpc/grillad_capture_submit',{...args,p_reference:parsed.reference,p_amount:parsed.amount,p_payer:payer,p_destination:c.destination,p_occurred:parsed.occurredAt,p_evidence:await digest(body.sms)},env.service));
  }
  if(body.action==='logout'){const r=await fetcher(base+'/auth/v1/logout?scope=local',{method:'POST',headers:{apikey:env.key,Authorization:bearer},redirect:'error',signal:AbortSignal.timeout(15000)});return r.ok?reply(200,{result:true}):reply(401,{error:'SESSION'});}
  // RPCs run under the caller token, never under service_role.
  if(body.action==='employee_accept'&&uuid.test(body.request)&&typeof body.invite==='string'&&/^[A-Za-z0-9_-]{32,128}$/.test(body.invite))return upstream(await post('/rest/v1/rpc/grillad_employee_accept',{p_request:body.request,p_token:body.invite},token));
  if(body.action==='central_overview')return upstream(await post('/rest/v1/rpc/grillad_central_overview',{},token));
  if(body.action==='workspace')return upstream(await post('/rest/v1/rpc/grillad_workspace',{},token));
  if(!uuid.test(body.org)||!uuid.test(body.site))return reply(400,{error:'SCOPE'});
  const scope={p_org:body.org,p_site:body.site};
  if(body.action==='referral'&&['list','generate','attach'].includes(body.operation)&&(body.code==null||typeof body.code==='string'&&body.code.length<=40))return upstream(await post('/rest/v1/rpc/grillad_referral',{...scope,p_action:body.operation,p_code:body.code??null},token));
  if(body.action==='support_list')return upstream(await post('/rest/v1/rpc/grillad_support_list',scope,token));
  if(body.action==='support_open'&&uuid.test(body.event)&&typeof body.subject==='string'&&typeof body.description==='string'&&body.subject.length<=120&&body.description.length<=2000)return upstream(await post('/rest/v1/rpc/grillad_support_open',{...scope,p_event:body.event,p_subject:body.subject,p_description:body.description},token));
  if(body.action==='push_register'&&typeof body.enabled==='boolean'){
   if(body.enabled&&(typeof body.token!=='string'||body.token.length<30||body.token.length>4096||!env.firebaseProject||body.project!==env.firebaseProject))return reply(400,{error:'PUSH_NOT_CONFIGURED'});
   return upstream(await post('/rest/v1/rpc/grillad_push_register',{...scope,p_token:body.enabled?body.token:null,p_project:body.enabled?body.project:null,p_enabled:body.enabled},token));
  }
  if(body.action==='renewal_status')return upstream(await post('/rest/v1/rpc/grillad_renewal_status',scope,token));
  if(body.action==='renewal_action'&&uuid.test(body.event)&&['renewal_request','central_request_cancel'].includes(body.operation)&&body.payload&&typeof body.payload==='object'&&!Array.isArray(body.payload))return upstream(await post('/rest/v1/rpc/grillad_renewal_action',{...scope,p_event:body.event,p_action:body.operation,p_payload:body.payload},token));
  if(body.action==='subscription_sms_candidate'&&uuid.test(body.request)&&['mtn_momo','orange_money'].includes(body.channel)&&typeof body.sms==='string'&&body.sms.length<=8000){
   const {parsePromoteurPaymentSms}=await import('./naxa-payment-sms.ts');const parsed=parsePromoteurPaymentSms(body.sms,body.channel);if(!parsed||parsed.direction!=='payer_debit'||!parsed.success||!parsed.reference||!Number.isSafeInteger(parsed.amount))return reply(400,{error:'SMS_REVIEW_REQUIRED'});
   const q=await post('/rest/v1/rpc/grillad_payment_quote',{...scope,p_request:body.request,p_channel:body.channel},token);if(!q.ok)return upstream(q);if(q.result?.channel!==body.channel||q.result?.status!=='pending'||!q.result?.destination||q.result?.amount!==parsed.amount)return reply(400,{error:'SMS_REVIEW_REQUIRED'});
   return reply(200,{result:{reference:parsed.reference,amount:parsed.amount,payer:parsed.payerNumber?.slice(-9)??'',occurred:parsed.occurredAt,review_required:true,level:3}});
  }
  if(body.action==='subscription_declare'&&uuid.test(body.request)&&typeof body.reference==='string'&&Number.isSafeInteger(body.amount)&&typeof body.payer==='string'&&typeof body.occurred==='string')return upstream(await post('/rest/v1/rpc/grillad_subscription_declare',{...scope,p_request:body.request,p_reference:body.reference,p_amount:body.amount,p_payer:body.payer,p_occurred:body.occurred},token));
  if(body.action==='payment_quote'&&uuid.test(body.request)&&['mtn_momo','orange_money','bank'].includes(body.channel))return upstream(await post('/rest/v1/rpc/grillad_payment_quote',{...scope,p_request:body.request,p_channel:body.channel},token));
  if(['offline_batch','offline_cancel'].includes(body.action)&&uuid.test(body.event)&&date.test(body.day)&&(body.cash==null||uuid.test(body.cash))&&Array.isArray(body.lines)&&body.lines.length>=1&&body.lines.length<=30)return upstream(await post(body.action==='offline_cancel'?'/rest/v1/rpc/grillad_offline_cancel':'/rest/v1/rpc/grillad_offline_batch',{...scope,p_event:body.event,p_day:body.day,p_cash:body.cash??null,p_lines:body.lines},token));
  if(body.action==='profile_get')return upstream(await post('/rest/v1/rpc/grillad_profile_get',scope,token));
  if(body.action==='profile_set'&&typeof body.name==='string'&&body.name.trim().length>=2&&body.name.length<=80&&Number.isSafeInteger(body.revision)&&body.revision>=0&&body.revision<=2147483647)return upstream(await post('/rest/v1/rpc/grillad_profile_set',{...scope,p_name:body.name,p_revision:body.revision},token));
  if(body.action==='prediction')return upstream(await post('/rest/v1/rpc/grillad_prediction',scope,token));
  function videoConfig(){try{const broker=new URL(env.videoBrokerUrl||''),media=new URL(env.videoMediaOrigin||'');if(broker.protocol!=='https:'||media.protocol!=='https:'||broker.username||broker.password||broker.search||broker.hash||media.username||media.password||media.pathname!=='/'||media.search||media.hash||typeof env.videoBrokerSecret!=='string'||env.videoBrokerSecret.length<32)return null;return{broker:broker.href,origin:media.origin}}catch{return null}}
  if(body.action==='security_list'){const x=await post('/rest/v1/rpc/grillad_security_list',scope,token);return x.ok?reply(200,{result:{...x.result,live_request_available:x.result?.available===true&&!!videoConfig()}}):upstream(x);}
  if(body.action==='security_live_session'||body.action==='security_live_revoke'){
   const config=videoConfig();if(!config)return reply(503,{error:'VIDEO_BROKER_NOT_CONFIGURED'});
   const isRevoke=body.action==='security_live_revoke';
   if(isRevoke?!uuid.test(body.session):!uuid.test(body.camera))return reply(400,{error:'VIDEO_INPUT'});
   const identity=await fetcher(base+'/auth/v1/user',{method:'GET',headers:{apikey:env.key,Authorization:bearer},redirect:'error',signal:AbortSignal.timeout(10000)});const user=identity.ok?await identity.json():null;if(!uuid.test(user?.id))return reply(401,{error:'SESSION'});
   if(!isRevoke){const allowed=await post('/rest/v1/rpc/grillad_security_list',scope,token);if(!allowed.ok||!allowed.result?.available||!Array.isArray(allowed.result.cameras)||!allowed.result.cameras.some(c=>c.id===body.camera))return reply(403,{error:'CAMERA_DENIED'});}
   const r=await fetcher(config.broker,{method:'POST',headers:{'Content-Type':'application/json','X-Grillad-Video-Secret':env.videoBrokerSecret},body:JSON.stringify({action:isRevoke?'revoke':'issue',app:'grillad',user:user.id,org:body.org,site:body.site,...(isRevoke?{session:body.session}:{camera:body.camera})}),redirect:'error',signal:AbortSignal.timeout(15000)});
   if(!r.ok)return reply(r.status===403?403:503,{error:'VIDEO_RELAY_REFUSED'});const ticket=await r.json().catch(()=>null);
   if(isRevoke)return ticket?.revoked===true?reply(200,{result:true}):reply(503,{error:'VIDEO_REVOKE_UNCONFIRMED'});
   if(!ticket||ticket.user!==user.id||ticket.org!==body.org||ticket.site!==body.site||ticket.camera!==body.camera||!uuid.test(ticket.session)||typeof ticket.authorization!=='string'||!/^Bearer [A-Za-z0-9_-]{43,160}$/.test(ticket.authorization))return reply(503,{error:'VIDEO_TICKET_INVALID'});
   const expires=Date.parse(ticket.expiresAt),now=Date.now();let whep;try{whep=new URL(ticket.whepUrl)}catch{return reply(503,{error:'VIDEO_TICKET_INVALID'})}
   if(!Number.isFinite(expires)||expires<=now+10000||expires>now+900000||whep.protocol!=='https:'||whep.origin!==config.origin||whep.username||whep.password||whep.search||whep.hash||!whep.pathname.endsWith('/whep'))return reply(503,{error:'VIDEO_TICKET_INVALID'});
   return reply(200,{result:{ok:true,session:ticket.session,whepUrl:whep.href,authorization:ticket.authorization,expiresAt:ticket.expiresAt,refreshAfterSeconds:Math.max(1,Math.min(780,Math.floor((expires-now)/1000)-5))}});
  }
  if(body.action==='pilotage_status')return upstream(await post('/rest/v1/rpc/grillad_pilotage_status',scope,token));
  if(body.action==='report'&&date.test(body.from)&&date.test(body.to)&&typeof body.network==='boolean'&&(body.family==null||['Porc','Poulet','Poisson','Brochettes','Omelettes'].includes(body.family))&&(body.actor==null||uuid.test(body.actor))&&(body.item==null||uuid.test(body.item)))return upstream(await post('/rest/v1/rpc/grillad_report',{...scope,p_from:body.from,p_to:body.to,p_network:body.network,p_family:body.family??null,p_actor:body.actor??null,p_item:body.item??null},token));
  if(body.action==='connect_list')return upstream(await post('/rest/v1/rpc/grillad_connect_list',scope,token));
  if(body.action==='connect_transition'&&uuid.test(body.order)&&uuid.test(body.event)&&['accepted','preparing','ready','handed','refused','cancelled'].includes(body.next))return upstream(await post(body.method&&body.method!=='cash'?'/rest/v1/rpc/grillad_connect_transition_method':'/rest/v1/rpc/grillad_connect_transition',{...scope,p_order:body.order,p_event:body.event,p_next:body.next,p_received:body.received??null,p_reason:body.reason??null,...(body.method&&body.method!=='cash'?{p_method:body.method}:{})},token));
  if(body.action==='daily_list')return upstream(await post('/rest/v1/rpc/grillad_daily_list',scope,token));
  if(body.action==='notice_feed')return upstream(await post('/rest/v1/rpc/grillad_notice_feed',scope,token));
  if(body.action==='notice_ack'&&typeof body.id==='string'&&body.id.length<=100)return upstream(await post('/rest/v1/rpc/grillad_notice_ack',{...scope,p_id:body.id},token));
  if(body.action==='notice_set'&&['sales','stock','cash','daily','attendance','connect','security','target','subscription'].includes(body.category)&&typeof body.enabled==='boolean')return upstream(await post('/rest/v1/rpc/grillad_notice_set',{...scope,p_category:body.category,p_enabled:body.enabled},token));
  if(body.action==='attendance_photo'&&uuid.test(body.id))return upstream(await post('/rest/v1/rpc/grillad_attendance_photo',{...scope,p_id:body.id},token));
  if(body.action==='attendance_status')return upstream(await post('/rest/v1/rpc/grillad_attendance_status',scope,token));
  if(body.action==='attendance_capture'&&uuid.test(body.event)&&['arrival','departure','departure_without_arrival'].includes(body.kind)&&typeof body.at==='string'&&typeof body.lat==='number'&&typeof body.lon==='number'&&typeof body.accuracy==='number'&&typeof body.photo==='string')return upstream(await post('/rest/v1/rpc/grillad_attendance_capture',{...scope,p_event:body.event,p_kind:body.kind,p_at:body.at,p_lat:body.lat,p_lon:body.lon,p_accuracy:body.accuracy,p_photo:body.photo},token));
  if(body.action==='receipt'&&uuid.test(body.sale))return upstream(await post('/rest/v1/rpc/grillad_receipt',{...scope,p_sale:body.sale},token));
  if(body.action==='snapshot'){
   if(!date.test(body.from)||!date.test(body.to))return reply(400,{error:'PERIOD'});
   return upstream(await post('/rest/v1/rpc/grillad_snapshot',{...scope,p_from:body.from,p_to:body.to},token));
  }
  if(body.action==='mutate'&&uuid.test(body.event)&&actions.has(body.operation)&&body.payload&&typeof body.payload==='object'&&!Array.isArray(body.payload))return upstream(await post('/rest/v1/rpc/grillad_action',{...scope,p_event:body.event,p_action:body.operation,p_payload:body.payload},token));
  return reply(400,{error:'ACTION'});
 }catch{return reply(503,{error:'SERVICE_UNAVAILABLE'});}
}
