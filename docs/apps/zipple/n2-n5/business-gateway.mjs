// Candidate API: reuse the N1 opaque-session contract. No service key on clients.
const hex=/^[0-9a-f]{64}$/;
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const toHex=b=>Array.from(b,x=>x.toString(16).padStart(2,"0")).join("");
const digest=async s=>toHex(new Uint8Array(await crypto.subtle.digest("SHA-256",new TextEncoder().encode(s))));
const token=()=>toHex(crypto.getRandomValues(new Uint8Array(32)));
const isObject=v=>v&&typeof v==="object"&&!Array.isArray(v);
const text=(v,max=160)=>typeof v==="string"&&v.trim().length>0&&v.length<=max?v.trim():null;
const integer=(v,min,max)=>Number.isSafeInteger(v)&&v>=min&&v<=max;
function invalid(){throw new Error("INVALID_INPUT")}
function id(v){if(typeof v!=="string"||!uuid.test(v))invalid();return v}
function choice(v,allowed){if(!allowed.includes(v))invalid();return v}
function amount(v,min=0){if(!integer(v,min,2147483647))invalid();return v}
function lineItems(v){if(!Array.isArray(v)||!v.length||v.length>50)invalid();return v.map(x=>{if(!isObject(x)||!integer(x.qty,1,1000))invalid();if(x.note!==undefined&&(typeof x.note!=="string"||x.note.length>500))invalid();return {item_id:id(x.item_id),qty:x.qty,...(x.note?{note:x.note.trim()}: {}),...(x.choices===undefined?{}:{choices:formulaChoices(x.choices)})}})}
function formulaChoices(v){if(!Array.isArray(v)||v.length>10)invalid();return v.map(x=>{if(!isObject(x))invalid();return {group_id:id(x.group_id),component_id:id(x.component_id)}})}
const publicActions=new Set(["guest_open","guest_menu","guest_order_create","guest_order_read","guest_feedback","guest_served","guest_post_feedback"]);
const professionalActions=new Set(["quote","referral_claim","snapshot","mode","menu_add","table_create","table_open","table_close","order_create","line_advance","delay","cancel","cash_open","cash_record","cash_close","erp_snapshot","ingredient_add","lot_receive","recipe_define","recipe_revise","produce","expense_record","supplier_add","purchase_create","purchase_batch_create","purchase_receive","supplier_pay","count_lot","procurement_snapshot","customer_add","customer_attach","followup_create","followup_complete","crm_snapshot","transfer_snapshot","transfer_request","transfer_decide","transfer_dispatch","transfer_receive","container_account","container_move","container_snapshot","container_finance_record","pilotage","zone_add","table_config","reserve_table","reservation_transition","catalog_update","floor_snapshot","station_grant","station_snapshot","station_availability","table_bill","table_rotate_qr","formula_define","formula_snapshot","group_pay","pickup_create","waitlist_add","waitlist_transition","category_set","catalog_channels","price_schedule","catalog_rules","formula_groups_define","capacity_set","capacity_snapshot","order_priority","call_number","operational_grant","bill_transfer","station_limit","catalog_base_set","station_window","no_show"]);
export function createBusinessGateway({rpc,origins,allowGuestOpen=false}){
 if(typeof rpc!=="function"||!Array.isArray(origins))throw Error("CONFIGURATION");
 return async req=>{
  const origin=req.headers.get("origin"),action=new URL(req.url).pathname.split("/").pop();
  const permitted=origin&&origins.includes(origin);
  const headers={"Content-Type":"application/json","Cache-Control":"no-store","Vary":"Origin",...(permitted?{"Access-Control-Allow-Origin":origin,"Access-Control-Allow-Headers":"authorization,content-type","Access-Control-Allow-Methods":"POST,OPTIONS"}:{})};
  const result=(status,body)=>new Response(JSON.stringify(body),{status,headers});
  if(origin&&!permitted)return result(403,{error:"DENIED"});
  if(req.method==="OPTIONS")return new Response(null,{status:permitted?204:403,headers});
  if(req.method!=="POST"||!req.headers.get("content-type")?.startsWith("application/json")||(!professionalActions.has(action)&&!publicActions.has(action)))return result(403,{error:"DENIED"});
  try{
   const raw=await req.text();if(raw.length>16000)invalid();const b=JSON.parse(raw);if(!isObject(b)||b.app_id!=="ZIPPLE")invalid();
   if(publicActions.has(action)){
    if(!permitted)return result(403,{error:"DENIED"});
    if(action==="guest_open"){
     // Explicit activation only; persisted N1-style rate guard runs in a separate RPC transaction.
     if(!allowGuestOpen)return result(503,{error:"GUEST_OPEN_NOT_CONFIGURED"});
     if(typeof b.qr!=="string"||!hex.test(b.qr))invalid();
     const qrHash=await digest(b.qr);if(await rpc("zp_guest_open_guard",{p_qr_hash:qrHash})!==true)return result(429,{error:"GUEST_OPEN_LIMIT_OR_UNAVAILABLE"});
     const guest=token();await rpc("zp_open_guest",{p_qr_hash:qrHash,p_guest_hash:await digest(guest)});
     const menu=await rpc("zp_guest_menu",{p_guest_hash:await digest(guest)});
     if(!menu)return result(403,{error:"DENIED"});
     return result(200,{guest_token:guest,menu});
    }
    const bearer=req.headers.get("authorization")??"";if(!bearer.startsWith("Guest ")||!hex.test(bearer.slice(6)))return result(401,{error:"DENIED"});
    const p_guest_hash=await digest(bearer.slice(6));let value;
    if(action==="guest_menu")value=await rpc("zp_guest_menu",{p_guest_hash});
    if(action==="guest_order_create")value=await rpc("zp_create_order",{p_access:null,p_guest_hash,p_site:id(b.site_id),p_channel:b.channel===undefined?"table":choice(b.channel,["table","counter"]),p_table_session:id(b.table_session_id),p_request:id(b.request_id),p_lines:lineItems(b.lines)});
    if(action==="guest_order_read")value=await rpc("zp_guest_order",{p_guest_hash,p_order:id(b.order_id)});
    if(action==="guest_served")value=await rpc("zp_guest_served",{p_guest_hash,p_order:id(b.order_id)});
    if(action==="guest_post_feedback"){if(!Array.isArray(b.ratings)||b.ratings.length<1||b.ratings.length>5)invalid();value=await rpc("zp_guest_post_feedback",{p_guest_hash,p_order:id(b.order_id),p_ratings:b.ratings.map(x=>{if(!isObject(x)||!integer(x.rating,1,5))invalid();return {post:choice(x.post,["kitchen","bar","snack","service","counter"]),rating:x.rating}})})}
    if(action==="guest_feedback"){if(!integer(b.rating,1,5)||typeof b.comment!=="string"||b.comment.length>1000)invalid();if(b.ratings!==undefined||b.reason!==undefined){if(!Array.isArray(b.ratings)||b.ratings.length>5)invalid();value=await rpc("zp_feedback_complete",{p_guest_hash,p_order:id(b.order_id),p_rating:b.rating,p_comment:b.comment,p_reason:b.reason?choice(b.reason,["wait","accuracy","quality","temperature","presentation","welcome","other"]):null,p_ratings:b.ratings.map(x=>{if(!isObject(x)||!integer(x.rating,1,5))invalid();return {post:choice(x.post,["kitchen","bar","snack","service","counter"]),rating:x.rating}})})}else value=await rpc("zp_submit_feedback",{p_guest_hash,p_order:id(b.order_id),p_rating:b.rating,p_comment:b.comment})}
    if(value==null)return result(403,{error:"DENIED"});return result(200,{data:value});
   }
   const bearer=req.headers.get("authorization")??"";if(!bearer.startsWith("Bearer ")||!hex.test(bearer.slice(7)))return result(401,{error:"DENIED"});
   const scope={p_access:await digest(bearer.slice(7)),p_site:id(b.site_id)};let name,args,value;
   switch(action){
    case "quote":name="zp_quote_intent";args={...scope,p_plan:choice(b.plan,["ACCESS","PREMIUM"]),p_cadence:choice(b.cadence,["monthly","annual"]),p_provider:choice(b.provider,["mtn_momo","orange_money"]),p_request:id(b.request_id)};break;
    case "referral_claim":name="zp_claim_referral";args=scope;break;
    case "snapshot":name="zp_business_snapshot";args=scope;break;
    case "mode":if(typeof b.bar!=="boolean"||typeof b.delivery!=="boolean")invalid();name="zp_site_mode";args={...scope,p_space:choice(b.space,["restaurant","snack_bar"]),p_bar:b.bar,p_delivery:b.delivery};break;
    case "menu_add":if(!text(b.name))invalid();name="zp_add_menu_item";args={...scope,p_name:text(b.name),p_post:choice(b.post,["kitchen","bar","snack"]),p_price:amount(b.price_xaf,1),p_qty:amount(b.qty)};break;
    case "table_create":{if(!text(b.label,80))invalid();const qr=token();value=await rpc("zp_manage_table",{...scope,p_label:text(b.label,80),p_qr_hash:await digest(qr)});return result(200,{data:{id:value,qr}})}
    case "pickup_create":{if(!text(b.label,80))invalid();const qr=token();value=await rpc("zp_pickup_create",{...scope,p_label:text(b.label,80),p_hash:await digest(qr)});return result(200,{data:{id:value,qr}})}
    case "table_rotate_qr":{const qr=token();const table=id(b.table_id);await rpc("zp_table_rotate_qr",{...scope,p_table:table,p_hash:await digest(qr)});return result(200,{data:{id:table,qr}})}
    case "table_open":name="zp_open_table";args={...scope,p_table:id(b.table_id)};break;
    case "table_close":name="zp_close_table";args={...scope,p_table_session:id(b.table_session_id)};break;
    case "order_create":name="zp_create_order";args={...scope,p_guest_hash:null,p_channel:choice(b.channel,["table","counter","takeaway"]),p_table_session:b.table_session_id==null?null:id(b.table_session_id),p_request:id(b.request_id),p_lines:lineItems(b.lines)};break;
    case "line_advance":name="zp_advance_line";args={...scope,p_order:id(b.order_id),p_item:id(b.item_id),p_next:choice(b.next,["preparing","ready","served"])};break;
    case "delay":if(!integer(b.minutes,1,240)||!text(b.reason,500)||b.reason.trim().length<5)invalid();name="zp_delay_explain";args={...scope,p_order:id(b.order_id),p_minutes:b.minutes,p_reason:text(b.reason,500)};break;
    case "cancel":if(!text(b.reason,500)||b.reason.trim().length<5)invalid();name="zp_cancel_unprepared_order";args={...scope,p_order:id(b.order_id),p_reason:text(b.reason,500)};break;
    case "cash_open":name="zp_open_cash";args={...scope,p_opening:amount(b.opening_xaf)};break;
    case "cash_record":name="zp_record_sale";args={...scope,p_cash:id(b.cash_id),p_order:id(b.order_id),p_request:id(b.request_id),p_method:choice(b.method,["cash","mtn_momo","orange_money","bank","card"]),p_amount:amount(b.amount_xaf,1),p_ref:b.reference==null?null:text(b.reference,160)};break;
    case "cash_close":name="zp_close_cash";args={...scope,p_cash:id(b.cash_id),p_counted:amount(b.counted_xaf)};break;
    case "erp_snapshot":name="zp_erp_snapshot";args=scope;break;
    case "ingredient_add":if(!text(b.name)||!text(b.unit,40)||typeof b.sku!=="string"||b.sku.length>80||!integer(b.reorder_milli,0,99999999999)||typeof b.supplier_whatsapp!=="string"||!/^(\d{9,15})?$/.test(b.supplier_whatsapp))invalid();name="zp_add_ingredient";args={...scope,p_name:text(b.name),p_sku:b.sku,p_unit:text(b.unit,40),p_reorder:b.reorder_milli,p_whatsapp:b.supplier_whatsapp};break;
    case "lot_receive":if(!text(b.label,100)||!text(b.supplier)||!integer(b.qty_milli,1,1000000000)||!(b.expires_on==null||typeof b.expires_on==="string"&&/^\d{4}-\d{2}-\d{2}$/.test(b.expires_on)))invalid();name="zp_receive_lot";args={...scope,p_ingredient:id(b.ingredient_id),p_request:id(b.request_id),p_label:text(b.label,100),p_supplier:text(b.supplier),p_qty:b.qty_milli,p_cost:amount(b.cost_xaf),p_expires:b.expires_on??null};break;
    case "recipe_define":if(!Array.isArray(b.components)||b.components.length<1||b.components.length>30)invalid();name="zp_define_recipe";args={...scope,p_item:id(b.item_id),p_components:b.components.map(c=>{if(!isObject(c)||!integer(c.qty_milli,1,1000000000))invalid();return {ingredient_id:id(c.ingredient_id),qty_milli:c.qty_milli}})};break;
    case "recipe_revise":if(!Array.isArray(b.components)||b.components.length<1||b.components.length>30||!integer(b.expected_version,1,2147483646)||!text(b.reason,500)||text(b.reason,500).length<5)invalid();name="zp_revise_recipe";args={...scope,p_item:id(b.item_id),p_request:id(b.request_id),p_expected:b.expected_version,p_reason:text(b.reason,500),p_components:b.components.map(c=>{if(!isObject(c)||!integer(c.qty_milli,1,1000000000))invalid();return {ingredient_id:id(c.ingredient_id),qty_milli:c.qty_milli}})};break;
    case "produce":if(!integer(b.servings,1,10000))invalid();name="zp_produce";args={...scope,p_item:id(b.item_id),p_request:id(b.request_id),p_servings:b.servings};break;
    case "expense_record":if(!text(b.label)||!text(b.reference)||typeof b.expense_date!=="string"||!/^\d{4}-\d{2}-\d{2}$/.test(b.expense_date))invalid();name="zp_record_expense";args={...scope,p_request:id(b.request_id),p_category:choice(b.category,["rent","utilities","transport","staff","maintenance","other"]),p_label:text(b.label),p_amount:amount(b.amount_xaf,1),p_method:choice(b.method,["cash","mtn_momo","orange_money","bank","card"]),p_reference:text(b.reference),p_date:b.expense_date};break;
    case "procurement_snapshot":name="zp_procurement_snapshot";args=scope;break;
    case "supplier_add":if(!text(b.name)||text(b.name).length<2||typeof b.phone!=="string"||b.phone.length>32||typeof b.whatsapp!=="string"||!/^(\d{9,15})?$/.test(b.whatsapp)||!integer(b.terms_days,0,365))invalid();name="zp_supplier_add";args={...scope,p_name:text(b.name),p_phone:b.phone,p_whatsapp:b.whatsapp,p_terms:b.terms_days};break;
    case "purchase_create":if(!text(b.reference,100)||!integer(b.qty_milli,1,1000000000))invalid();name="zp_purchase_create";args={...scope,p_supplier:id(b.supplier_id),p_ingredient:id(b.ingredient_id),p_request:id(b.request_id),p_reference:text(b.reference,100),p_qty:b.qty_milli,p_total:amount(b.total_xaf,1)};break;
    case "purchase_batch_create":if(!text(b.reference,100)||!Array.isArray(b.lines)||b.lines.length<2||b.lines.length>50)invalid();name="zp_purchase_batch_create";args={...scope,p_supplier:id(b.supplier_id),p_request:id(b.request_id),p_reference:text(b.reference,100),p_lines:b.lines.map(l=>{if(!isObject(l)||!integer(l.qty_milli,1,1000000000))invalid();return {ingredient_id:id(l.ingredient_id),qty_milli:l.qty_milli,total_xaf:amount(l.total_xaf,1)}})};break;
    case "purchase_receive":if(!text(b.label,100)||!integer(b.qty_milli,1,1000000000)||!(b.expires_on==null||typeof b.expires_on==="string"&&/^\d{4}-\d{2}-\d{2}$/.test(b.expires_on)))invalid();name="zp_purchase_receive";args={...scope,p_purchase:id(b.purchase_id),p_request:id(b.request_id),p_qty:b.qty_milli,p_label:text(b.label,100),p_expires:b.expires_on??null};break;
    case "supplier_pay":if(!text(b.reference)||text(b.reference).length<4)invalid();name="zp_supplier_pay";args={...scope,p_purchase:id(b.purchase_id),p_request:id(b.request_id),p_amount:amount(b.amount_xaf,1),p_method:choice(b.method,["cash","bank","mtn_momo","orange_money","card"]),p_reference:text(b.reference)};break;
    case "count_lot":if(!integer(b.expected_milli,0,1000000000)||!integer(b.counted_milli,0,1000000000)||!text(b.reason,500)||text(b.reason,500).length<5)invalid();name="zp_count_lot";args={...scope,p_lot:id(b.lot_id),p_request:id(b.request_id),p_expected:b.expected_milli,p_counted:b.counted_milli,p_reason:text(b.reason,500)};break;
    case "customer_add":if(!text(b.name)||typeof b.phone!=="string"||!/^(\d{9,15})?$/.test(b.phone))invalid();name="zp_customer_add";args={...scope,p_name:text(b.name),p_phone:b.phone};break;
    case "customer_attach":name="zp_customer_attach";args={...scope,p_customer:id(b.customer_id),p_order:id(b.order_id)};break;
    case "followup_create":if(!text(b.title)||typeof b.due_on!=="string"||!/^\d{4}-\d{2}-\d{2}$/.test(b.due_on))invalid();name="zp_followup_create";args={...scope,p_customer:id(b.customer_id),p_request:id(b.request_id),p_title:text(b.title),p_channel:choice(b.channel,["telephone","whatsapp","in_person"]),p_due:b.due_on};break;
    case "followup_complete":name="zp_followup_complete";args={...scope,p_followup:id(b.followup_id)};break;
    case "crm_snapshot":name="zp_crm_snapshot";args=scope;break;
    case "transfer_snapshot":name="zp_transfer_snapshot";args=scope;break;
    case "transfer_request":if(!integer(b.qty_milli,1,1000000000))invalid();name="zp_transfer_request";args={...scope,p_destination:id(b.destination_site),p_lot:id(b.source_lot),p_ingredient:id(b.destination_ingredient),p_request:id(b.request_id),p_qty:b.qty_milli};break;
    case "transfer_decide":name="zp_transfer_decide";args={...scope,p_transfer:id(b.transfer_id),p_decision:choice(b.decision,["approved","cancelled"])};break;
    case "transfer_dispatch":name="zp_transfer_dispatch";args={...scope,p_transfer:id(b.transfer_id)};break;
    case "transfer_receive":if(!integer(b.qty_milli,0,1000000000)||typeof b.reason!=="string"||b.reason.length>500)invalid();name="zp_transfer_receive";args={...scope,p_transfer:id(b.transfer_id),p_qty:b.qty_milli,p_reason:b.reason};break;
    case "container_snapshot":name="zp_container_snapshot";args=scope;break;
    case "container_account":if(!text(b.label,100)||!integer(b.unit_deposit_xaf,0,10000000))invalid();name="zp_container_account";args={...scope,p_supplier:b.supplier_id==null?null:id(b.supplier_id),p_customer:b.customer_id==null?null:id(b.customer_id),p_label:text(b.label,100),p_unit:b.unit_deposit_xaf};break;
    case "container_finance_record":if(!text(b.reference)||text(b.reference).length<4)invalid();name="zp_container_finance_record";args={...scope,p_event:id(b.event_id),p_request:id(b.request_id),p_amount:amount(b.amount_xaf,1),p_method:choice(b.method,["cash","bank","mtn_momo","orange_money","card"]),p_reference:text(b.reference)};break;
    case "container_move":if(!integer(b.qty,1,1000000)||typeof b.reason!=="string"||b.reason.length>500)invalid();name="zp_container_move";args={...scope,p_account:id(b.account_id),p_request:id(b.request_id),p_kind:choice(b.kind,["issued","returned","lost"]),p_qty:b.qty,p_reason:b.reason};break;
    case "pilotage":if(typeof b.start!=="string"||typeof b.end!=="string"||!(/^\d{4}-\d{2}-\d{2}$/.test(b.start)&&/^\d{4}-\d{2}-\d{2}$/.test(b.end)))invalid();name="zp_pilotage";args={...scope,p_start:b.start,p_end:b.end};break;
    case "zone_add":if(!text(b.name,80))invalid();name="zp_zone_add";args={...scope,p_name:text(b.name,80)};break;
    case "table_config":if(!integer(b.seats,1,100))invalid();name="zp_table_config";args={...scope,p_table:id(b.table_id),p_zone:b.zone_id==null?null:id(b.zone_id),p_seats:b.seats};break;
    case "reserve_table":if(!text(b.guest_name)||!integer(b.party_size,1,100)||typeof b.starts_at!=="string"||typeof b.ends_at!=="string"||!Number.isFinite(Date.parse(b.starts_at))||!Number.isFinite(Date.parse(b.ends_at)))invalid();name="zp_reserve_table";args={...scope,p_table:id(b.table_id),p_request:id(b.request_id),p_name:text(b.guest_name),p_party:b.party_size,p_start:new Date(b.starts_at).toISOString(),p_end:new Date(b.ends_at).toISOString()};break;
    case "reservation_transition":name="zp_reservation_transition";args={...scope,p_reservation:id(b.reservation_id),p_next:choice(b.next,["seated","cancelled","expired"])};break;
    case "catalog_update":if(!text(b.category,80)||!["subcategory","description","variant"].every(k=>typeof b[k]==="string"&&b[k].length<=(k==="description"?500:80))||!integer(b.prep_minutes,1,240)||!integer(b.low_threshold,0,2147483647)||typeof b.active!=="boolean"||![b.available_from,b.available_until].every(x=>x==null||typeof x==="string"&&/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(x)))invalid();name="zp_catalog_update";args={...scope,p_item:id(b.item_id),p_category:text(b.category,80),p_subcategory:b.subcategory,p_description:b.description,p_variant:b.variant,p_kind:choice(b.kind,["standard","variant","supplement","formula"]),p_minutes:b.prep_minutes,p_low:b.low_threshold,p_active:b.active,p_from:b.available_from??null,p_until:b.available_until??null};break;
    case "floor_snapshot":name="zp_floor_snapshot";args=scope;break;
    case "station_grant":if(typeof b.enabled!=="boolean")invalid();name="zp_station_grant";args={...scope,p_member:id(b.member_id),p_post:choice(b.post,["kitchen","bar","snack"]),p_enabled:b.enabled};break;
    case "station_snapshot":name="zp_station_snapshot";args=scope;break;
    case "station_availability":if(typeof b.active!=="boolean")invalid();name="zp_station_availability";args={...scope,p_item:id(b.item_id),p_active:b.active};break;
    case "table_bill":name="zp_table_bill";args={...scope,p_session:id(b.table_session_id)};break;
    case "formula_snapshot":name="zp_formula_snapshot";args=scope;break;
    case "formula_define":if(!Array.isArray(b.components)||b.components.length<1||b.components.length>20)invalid();name="zp_formula_define";args={...scope,p_formula:id(b.formula_id),p_components:b.components.map(x=>{if(!isObject(x)||!integer(x.qty,1,100))invalid();return {component_id:id(x.component_id),qty:x.qty}})};break;
    case "group_pay":if(!Array.isArray(b.order_ids)||!b.order_ids.length||b.order_ids.length>50)invalid();name="zp_record_group_sale";args={...scope,p_cash:id(b.cash_id),p_session:id(b.table_session_id),p_orders:b.order_ids.map(id),p_request:id(b.request_id),p_method:choice(b.method,["cash","mtn_momo","orange_money","bank","card"]),p_amount:amount(b.amount_xaf,1),p_ref:b.reference==null?null:text(b.reference)};break;
    case "waitlist_add":if(!text(b.guest_name)||!integer(b.party_size,1,100))invalid();name="zp_waitlist_add";args={...scope,p_request:id(b.request_id),p_guest:text(b.guest_name),p_party:b.party_size};break;
    case "waitlist_transition":name="zp_waitlist_transition";args={...scope,p_wait:id(b.waitlist_id),p_next:choice(b.next,["seated","cancelled"]),p_table:b.table_id==null?null:id(b.table_id)};break;
    case "category_set":if(!text(b.category,80)||typeof b.active!=="boolean")invalid();name="zp_category_set";args={...scope,p_category:text(b.category,80),p_active:b.active};break;
    case "catalog_channels":if(!Array.isArray(b.channels)||!b.channels.length||b.channels.length>3)invalid();name="zp_catalog_channels";args={...scope,p_item:id(b.item_id),p_channels:b.channels.map(x=>choice(x,["table","counter","takeaway"]))};break;
    case "price_schedule":if(!text(b.reason,500)||b.reason.trim().length<5||typeof b.ends_at!=="string"||!Number.isFinite(Date.parse(b.ends_at))||!(b.starts_at==null||typeof b.starts_at==="string"&&Number.isFinite(Date.parse(b.starts_at))))invalid();name="zp_price_schedule";args={...scope,p_item:id(b.item_id),p_channel:choice(b.channel,["all","table","counter","takeaway"]),p_price:amount(b.price_xaf,1),p_start:b.starts_at??null,p_end:b.ends_at,p_reason:text(b.reason,500)};break;
    case "catalog_rules":name="zp_catalog_rules";args=scope;break;
    case "formula_groups_define":if(!Array.isArray(b.groups)||!b.groups.length||b.groups.length>10)invalid();name="zp_formula_groups_define";args={...scope,p_formula:id(b.formula_id),p_groups:b.groups.map(x=>{if(!isObject(x)||!text(x.name,80)||typeof x.required!=="boolean"||!integer(x.qty,1,100)||!Array.isArray(x.options)||!x.options.length||x.options.length>20)invalid();return {name:text(x.name,80),required:x.required,qty:x.qty,options:x.options.map(o=>{if(!isObject(o)||!integer(o.delta_xaf,-1000000,1000000))invalid();return {component_id:id(o.component_id),delta_xaf:o.delta_xaf}})}})};break;
    case "capacity_set":if(!integer(b.parallel_slots,1,100))invalid();name="zp_capacity_set";args={...scope,p_post:choice(b.post,["kitchen","bar","snack"]),p_slots:b.parallel_slots};break;
    case "capacity_snapshot":name="zp_capacity_snapshot";args=scope;break;
    case "order_priority":if(!integer(b.priority,0,2)||!text(b.reason,500)||b.reason.trim().length<5)invalid();name="zp_order_priority";args={...scope,p_order:id(b.order_id),p_priority:b.priority,p_reason:text(b.reason,500)};break;
    case "call_number":name="zp_call_number";args={...scope,p_order:id(b.order_id)};break;
    case "no_show":if(!text(b.reason,500)||b.reason.trim().length<5)invalid();name="zp_no_show";args={...scope,p_order:id(b.order_id),p_reason:text(b.reason,500)};break;
    case "station_window":if(![b.available_from,b.available_until].every(x=>x===null||typeof x==="string"&&/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(x)))invalid();name="zp_station_window";args={...scope,p_item:id(b.item_id),p_from:b.available_from,p_until:b.available_until};break;
    case "station_limit":if(b.limit!==null&&!integer(b.limit,0,2147483647))invalid();name="zp_station_limit";args={...scope,p_item:id(b.item_id),p_limit:b.limit};break;
    case "catalog_base_set":if(!text(b.name,160)||typeof b.sku!=="string"||b.sku.length>80||!text(b.sale_unit,80)||!text(b.reason,500))invalid();name="zp_catalog_base_set";args={...scope,p_item:id(b.item_id),p_name:text(b.name,160),p_sku:b.sku,p_unit:text(b.sale_unit,80),p_price:amount(b.price_xaf,1),p_reason:text(b.reason,500)};break;
    case "bill_transfer":name="zp_bill_transfer";args={...scope,p_order:id(b.order_id),p_source:id(b.source_session_id),p_target:id(b.target_session_id),p_request:id(b.request_id),p_reason:text(b.reason)};break;
    case "operational_grant":if(typeof b.enabled!=="boolean")invalid();name="zp_operational_grant";args={...scope,p_member:id(b.member_id),p_role:choice(b.role,["server","floor","cashier"]),p_enabled:b.enabled};break;
    default:return result(403,{error:"DENIED"});
   }
   value=await rpc(name,args);
   return result(200,{data:value??null});
  }catch(error){
   const safe=["DENIED","SUBSCRIPTION_OR_ROLE_REQUIRED","SUBSCRIPTION_REQUIRED","OFFER_DENIED","ITEM_UNAVAILABLE","IDEMPOTENCY_CONFLICT","TABLE_HAS_OPEN_ORDERS","INVALID_TRANSITION","CASH_CLOSED","SALE_NOT_SETTLEABLE","CHANNEL_DENIED","TABLE_CLOSED","POST_DENIED","CANCELLATION_REQUIRES_REVIEW","MODE_CHANGE_REQUIRES_MIGRATION","EXPIRED_LOT","RECIPE_REQUIRES_EMPTY_ITEM","RECIPE_VERSION_REQUIRED","STALE_RECIPE_VERSION","INVALID_COMPONENTS","INVALID_PRODUCTION","INGREDIENT_SHORTAGE","INVALID_EXPENSE_DATE","RECIPE_REQUIRES_NO_OPEN_ORDERS","PRODUCTION_COST_SHORTAGE","RECEIPT_EXCEEDS_PURCHASE","PAYMENT_EXCEEDS_DEBT","STALE_INVENTORY_COUNT","COUNT_REQUIRES_REVIEW","CUSTOMER_REVIEW_REQUIRED","CUSTOMER_LINK_LOCKED","PREMIUM_REQUIRED","TRANSFER_ITEM_MISMATCH","TRANSFER_COUNT_REVIEW","INVALID_COUNTERPARTY","INVALID_PURCHASE_LINES","INVALID_CONTAINER_MOVEMENT","CONTAINER_BALANCE_EXCEEDED","INVALID_DEPOSIT_PAYMENT","DEPOSIT_EVENT_ALREADY_RECORDED","DEPOSIT_REFUND_EXCEEDS_BALANCE","DEPOSIT_REFERENCE_USED","INVALID_PERIOD","RESERVATION_CAPACITY","RESERVATION_OVERLAP","RESERVATION_UNAVAILABLE","INVALID_WINDOW","INVALID_RATINGS","TABLE_MUST_BE_CLOSED","FORMULA_REQUIRES_EMPTY_ITEM","FORMULA_VERSION_REQUIRED","FORMULA_STOCK_MANAGED_BY_COMPONENTS","FORMULA_ALLOCATION_MISMATCH","INVALID_GROUP","INVALID_FORMULA_CHOICES","INVALID_PRICE_RULE","PRICE_RULE_OVERLAP","INVALID_DELAY","INVALID_PRIORITY","INVALID_BILL_TRANSFER"];
   const code=String(error?.message??"");if(code==="INVALID_INPUT"||error instanceof SyntaxError)return result(400,{error:"INVALID_INPUT"});
   if(safe.includes(code))return result(code==="DENIED"||code.includes("REQUIRED")?403:409,{error:code});
   return result(503,{error:"OPERATION_UNAVAILABLE"});
  }
 };
}
// Deliberately absent: subscription confirmation, privileged SQL, user provisioning.
