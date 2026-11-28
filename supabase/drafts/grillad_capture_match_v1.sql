begin;
create or replace function grillad_private.subscription_proof(p_request uuid,p_level smallint,p_actor uuid,p_reference text,p_amount bigint,p_payer text,p_destination text,p_occurred timestamptz,p_hash text) returns jsonb
language plpgsql security definer set search_path=pg_catalog as $fn$
declare q grillad_private.central_requests%rowtype;i famille_core.payment_intents%rowtype;d grillad_private.subscription_intent_destinations%rowtype;old grillad_private.subscription_proofs%rowtype;debit grillad_private.subscription_proofs%rowtype;credit grillad_private.subscription_proofs%rowtype;
begin
 if p_level is null or p_level not in (1,2) or p_hash is null or p_hash!~'^[0-9a-f]{64}$' or not exists(select 1 from auth.users where id=p_actor) then raise exception 'GRILLAD_PROOF_INPUT' using errcode='22023';end if;
 select * into q from grillad_private.central_requests where id=p_request and kind='renewal' for update;
 if not found then raise exception 'GRILLAD_REQUEST' using errcode='22023';end if;
 select pi.* into i from famille_core.payment_intents pi join grillad_private.renewal_payment_links l on l.intent_id=pi.id where l.request_id=q.id;
 select * into d from grillad_private.subscription_intent_destinations where intent=i.id;
 if not found or i.status<>'pending' or q.status<>'pending' or i.expires_at<=now() or p_amount is distinct from i.expected_amount_fcfa or p_destination is distinct from d.reference or p_payer is null or p_payer!~'^[0-9]{9}$' or p_reference is null or length(regexp_replace(p_reference,'[^A-Za-z0-9]','','g'))<5 or length(p_reference)>160 or p_occurred is null or p_occurred<i.created_at or p_occurred>now()+interval '2 minutes' or (p_level=1 and p_actor<>q.actor) or (p_level=2 and p_actor=q.actor) then raise exception 'GRILLAD_PROOF_MISMATCH' using errcode='22023';end if;
 select * into old from grillad_private.subscription_proofs where intent=i.id and level=p_level;
 if found then if old.evidence_hash<>p_hash or old.actor<>p_actor or old.reference<>btrim(p_reference) or old.amount<>p_amount or old.payer_tail<>p_payer or old.occurred_at<>p_occurred then raise exception 'GRILLAD_PROOF_CONFLICT' using errcode='22023';end if;else
 insert into grillad_private.subscription_proofs(intent,level,actor,channel,reference,amount,payer_tail,destination,occurred_at,evidence_hash) values(i.id,p_level,p_actor,i.channel,btrim(p_reference),p_amount,p_payer,d.reference,p_occurred,p_hash);end if;
 select * into debit from grillad_private.subscription_proofs where intent=i.id and level=1;
 select * into credit from grillad_private.subscription_proofs where intent=i.id and level=2;
 if debit.intent is null or credit.intent is null then return jsonb_build_object('status','awaiting_independent_proof','level',p_level);end if;
 -- NAXA Admin uses the common normalized financial reference. Distinct references remain manual review.
 if debit.normalized_reference<>credit.normalized_reference or debit.actor=credit.actor or debit.payer_tail<>credit.payer_tail or debit.channel<>credit.channel or debit.destination<>credit.destination or abs(extract(epoch from debit.occurred_at-credit.occurred_at))>300 then return jsonb_build_object('status','manual_review','level',3);end if;
 return grillad_private.payment_confirm(q.id,credit.actor,credit.reference,credit.amount,credit.occurred_at,credit.evidence_hash);
end $fn$;

-- Find only one pending GRILLAD subscription with an existing independent debit and common reference.
-- Never search using amount alone; no customer or NAXA data is accessed.
create function grillad_private.capture_match(p_actor uuid,p_session uuid,p_device uuid,p_hash text,p_channel text,p_reference text,p_amount bigint,p_payer text,p_occurred timestamptz) returns uuid
language plpgsql security definer set search_path=pg_catalog as $fn$
declare d grillad_private.subscription_capture_devices%rowtype; matches uuid[];
begin
 if p_actor is null or not exists(select 1 from auth.sessions where id=p_session and user_id=p_actor) then raise exception 'GRILLAD_CAPTURE_SESSION' using errcode='42501';end if;
 select x.* into d from grillad_private.subscription_capture_devices x join grillad_private.subscription_destinations y on y.channel=x.channel and y.reference=x.destination and y.enabled where x.id=p_device and x.actor=p_actor and x.token_hash=p_hash and x.channel=p_channel and x.revoked_at is null;
 if not found then raise exception 'GRILLAD_ADMIN_DEVICE' using errcode='42501';end if;
 if p_reference is null or length(p_reference)>160 or length(regexp_replace(p_reference,'[^A-Za-z0-9]','','g'))<5 or p_amount is null or p_amount<=0 or p_payer is null or p_payer!~'^[0-9]{9}$' or p_occurred is null or p_occurred>now()+interval '2 minutes' then return null;end if;
 select array_agg(z.id) into matches from (
 select q.id from grillad_private.central_requests q join grillad_private.renewal_payment_links l on l.request_id=q.id join famille_core.payment_intents i on i.id=l.intent_id join grillad_private.subscription_intent_destinations dst on dst.intent=i.id join grillad_private.subscription_proofs p on p.intent=i.id and p.level=1
 where q.kind='renewal' and q.status='pending' and q.actor<>p_actor and p.actor=q.actor and i.status='pending' and i.expires_at>now() and p_occurred>=i.created_at and i.expected_amount_fcfa=p_amount and i.channel=d.channel and dst.channel=d.channel and dst.reference=d.destination and p.destination=d.destination and p.channel=d.channel and p.normalized_reference=upper(regexp_replace(p_reference,'[^A-Za-z0-9]','','g')) and p.amount=p_amount and p.payer_tail=p_payer and abs(extract(epoch from p.occurred_at-p_occurred))<=300 limit 2
 ) z;
 if cardinality(matches)=1 then return matches[1];end if;return null;
end $fn$;
create function public.grillad_capture_match(p_actor uuid,p_session uuid,p_device uuid,p_hash text,p_channel text,p_reference text,p_amount bigint,p_payer text,p_occurred timestamptz) returns uuid language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.capture_match(p_actor,p_session,p_device,p_hash,p_channel,p_reference,p_amount,p_payer,p_occurred)$fn$;
revoke all on function grillad_private.capture_match(uuid,uuid,uuid,text,text,text,bigint,text,timestamptz),public.grillad_capture_match(uuid,uuid,uuid,text,text,text,bigint,text,timestamptz) from public,anon,authenticated;
grant execute on function grillad_private.capture_match(uuid,uuid,uuid,text,text,text,bigint,text,timestamptz),public.grillad_capture_match(uuid,uuid,uuid,text,text,text,bigint,text,timestamptz) to service_role;
commit;
