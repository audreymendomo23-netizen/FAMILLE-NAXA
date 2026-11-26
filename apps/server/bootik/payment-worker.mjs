import{createHash}from'node:crypto';
export async function captureCredit(db,deviceToken,p){
 if(typeof deviceToken!=='string'||!/^[0-9a-f]{64}$/.test(deviceToken)||!p||!['mtn_momo','orange_money'].includes(p.channel)||p.direction!=='merchant_credit'||p.success!==true||p.sender_origin_id!==(p.channel==='mtn_momo'?'MobileMoney':'OrangeMoney'))throw Error('INVALID_CAPTURE');
 const tokenHash=createHash('sha256').update(deviceToken).digest('hex');
 const q=await db.query('select bootik.bk_capture_credit($1,$2,$3,$4,$5,$6,$7) as id',[tokenHash,p.channel,p.reference,p.amount_fcfa,p.destination,p.provider_at,p.evidence_sha]);
 return q.rows[0].id;
}
export async function reconcilePending(db){
 const q=await db.query("select i.id from bootik.bk_payment_intents i join bootik.bk_payer_proofs d on d.intent_id=i.id join bootik.bk_merchant_proofs c on c.channel=d.channel and c.reference=d.reference where i.state='awaiting_verification' and i.expires_at+interval '24 hours'>now() and c.amount_fcfa=d.amount_fcfa and c.destination=d.destination and c.evidence_sha<>d.evidence_sha and abs(extract(epoch from(c.provider_at-d.provider_at)))<=1800 order by i.created_at limit 100");
 let count=0;for(const row of q.rows){const r=await db.query('select bootik.bk_reconcile_subscription($1) as id',[row.id]);if(r.rows[0].id)count++}return count;
}
