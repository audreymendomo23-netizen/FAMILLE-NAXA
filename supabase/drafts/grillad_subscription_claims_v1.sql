begin;
-- NAXA reference-claim registry: a financial reference belongs to one subscription intent globally.
create table grillad_private.subscription_reference_claims(
 normalized_reference text primary key check(length(normalized_reference) between 5 and 160),
 intent uuid not null references famille_core.payment_intents(id),created_at timestamptz not null default now()
);
alter table grillad_private.subscription_reference_claims enable row level security;
revoke all on grillad_private.subscription_reference_claims from public,anon,authenticated;
insert into grillad_private.subscription_reference_claims(normalized_reference,intent)
select distinct normalized_reference,intent from grillad_private.subscription_proofs;
create function grillad_private.subscription_reference_claim() returns trigger language plpgsql security definer set search_path=pg_catalog as $fn$
declare n text;owner_intent uuid;
begin
 n:=upper(regexp_replace(new.reference,'[^A-Za-z0-9]','','g'));
 insert into grillad_private.subscription_reference_claims(normalized_reference,intent) values(n,new.intent) on conflict(normalized_reference) do nothing;
 select intent into owner_intent from grillad_private.subscription_reference_claims where normalized_reference=n;
 if owner_intent is distinct from new.intent then raise exception 'GRILLAD_REFERENCE_ALREADY_CLAIMED' using errcode='23505';end if;
 return new;
end $fn$;
revoke all on function grillad_private.subscription_reference_claim() from public,anon,authenticated;
create trigger grillad_reference_claim_before_insert before insert on grillad_private.subscription_proofs for each row execute function grillad_private.subscription_reference_claim();
commit;
