begin;
create table grillad_private.identity_reviews(
 event uuid primary key,user_id uuid references auth.users(id),operator uuid not null references auth.users(id),
 phone_hash text not null check(phone_hash~'^[0-9a-f]{64}$'),proof_hash text not null check(proof_hash~'^[0-9a-f]{64}$'),
 kind text not null check(kind in ('owner','employee','recovery')),request_id uuid,created_at timestamptz not null default now(),
 unique(proof_hash),check(kind<>'recovery' or (user_id is not null and request_id is not null))
);
alter table grillad_private.identity_reviews enable row level security;
revoke all on grillad_private.identity_reviews from public,anon,authenticated;
create function grillad_private.identity_review(p_event uuid,p_operator uuid,p_user uuid,p_phone_hash text,p_proof_hash text,p_kind text,p_request uuid) returns boolean
language plpgsql security definer set search_path=pg_catalog as $fn$
declare old grillad_private.identity_reviews%rowtype;actual text;
begin
 if p_event is null or p_operator is null or p_user=p_operator or p_kind is null or p_kind not in ('owner','employee','recovery') or p_phone_hash is null or p_phone_hash!~'^[0-9a-f]{64}$' or p_proof_hash is null or p_proof_hash!~'^[0-9a-f]{64}$' or not exists(select 1 from auth.users where id=p_operator) then raise exception 'GRILLAD_REVIEW_INPUT' using errcode='22023';end if;
 if p_user is not null then
  select encode(sha256(convert_to('grillad:+'||ltrim(to_jsonb(u)->>'phone','+'),'UTF8')),'hex') into actual from auth.users u where id=p_user and to_jsonb(u)->>'phone_confirmed_at' is not null;
  if actual is distinct from p_phone_hash then raise exception 'GRILLAD_IDENTITY_MISMATCH' using errcode='42501';end if;
 end if;
 if p_kind='recovery' then
  if p_user is null or not exists(select 1 from famille_private.account_app_access where user_id=p_user and app_code='grillad' and status='active') or not exists(select 1 from famille_private.recovery_requests where id=p_request and app_code='grillad' and login_hash=p_phone_hash and status in ('pending','identity_check') and (user_id is null or user_id=p_user)) then raise exception 'GRILLAD_RECOVERY_DENIED' using errcode='42501';end if;
 end if;
 select * into old from grillad_private.identity_reviews where event=p_event;
 if found then if (old.operator,old.user_id,old.phone_hash,old.proof_hash,old.kind,old.request_id) is distinct from (p_operator,p_user,p_phone_hash,p_proof_hash,p_kind,p_request) then raise exception 'GRILLAD_REVIEW_CONFLICT' using errcode='22023';end if;return true;end if;
 insert into grillad_private.identity_reviews(event,user_id,operator,phone_hash,proof_hash,kind,request_id) values(p_event,p_user,p_operator,p_phone_hash,p_proof_hash,p_kind,p_request);
 if p_kind='recovery' then update famille_private.recovery_requests set user_id=p_user,reviewed_by=p_operator,reviewed_at=now(),review_reason='central_identity_verified',status='identity_check' where id=p_request;end if;
 return true;
end $fn$;
create function public.grillad_identity_review(p_event uuid,p_operator uuid,p_user uuid,p_phone_hash text,p_proof_hash text,p_kind text,p_request uuid) returns boolean language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.identity_review(p_event,p_operator,p_user,p_phone_hash,p_proof_hash,p_kind,p_request)$fn$;
revoke all on function grillad_private.identity_review(uuid,uuid,uuid,text,text,text,uuid),public.grillad_identity_review(uuid,uuid,uuid,text,text,text,uuid) from public,anon,authenticated;
grant execute on function grillad_private.identity_review(uuid,uuid,uuid,text,text,text,uuid),public.grillad_identity_review(uuid,uuid,uuid,text,text,text,uuid) to service_role;
commit;
