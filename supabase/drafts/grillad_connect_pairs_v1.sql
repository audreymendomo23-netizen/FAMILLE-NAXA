begin;
create table grillad_private.connect_table_pairs(
 link uuid not null references grillad_private.connect_links(id),zipple_hash text not null unique check(zipple_hash~'^[0-9a-f]{64}$'),
 operator uuid not null references auth.users(id),proof_hash text not null check(proof_hash~'^[0-9a-f]{64}$'),enabled boolean not null default true,
 primary key(link,zipple_hash),created_at timestamptz not null default now()
);
alter table grillad_private.connect_table_pairs enable row level security;
revoke all on grillad_private.connect_table_pairs from public,anon,authenticated;
create function grillad_private.connect_pair_set(p_link uuid,p_zipple_hash text,p_operator uuid,p_proof text,p_enabled boolean) returns boolean language plpgsql security definer set search_path=pg_catalog as $fn$
begin
 if p_enabled is null or p_zipple_hash is null or p_zipple_hash!~'^[0-9a-f]{64}$' or p_proof is null or p_proof!~'^[0-9a-f]{64}$' or not exists(select 1 from auth.users where id=p_operator) then raise exception 'GRILLAD_PAIR_INPUT' using errcode='22023';end if;
 if not p_enabled then update grillad_private.connect_table_pairs set enabled=false where link=p_link and zipple_hash=p_zipple_hash;return found;end if;
 if not grillad_private.connect_active(p_link) then raise exception 'GRILLAD_PARTNER_UNAVAILABLE' using errcode='42501';end if;
 insert into grillad_private.connect_table_pairs(link,zipple_hash,operator,proof_hash) values(p_link,p_zipple_hash,p_operator,p_proof) on conflict(link,zipple_hash) do nothing;
 if not exists(select 1 from grillad_private.connect_table_pairs where link=p_link and zipple_hash=p_zipple_hash and operator=p_operator and proof_hash=p_proof and enabled) then raise exception 'GRILLAD_PAIR_CONFLICT' using errcode='22023';end if;
 return true;
end $fn$;
create function grillad_private.connect_pair_check(p_hash text,p_zipple_hash text) returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $fn$
declare l grillad_private.connect_links%rowtype;
begin
 l:=grillad_private.connect_qr(p_hash);
 if not exists(select 1 from grillad_private.connect_table_pairs where link=l.id and zipple_hash=p_zipple_hash and enabled) then raise exception 'GRILLAD_PAIR_DENIED' using errcode='42501';end if;
 return jsonb_build_object('approved',true,'separate_orders',true,'separate_tenders',true);
end $fn$;
create function public.grillad_connect_pair_set(p_link uuid,p_zipple_hash text,p_operator uuid,p_proof text,p_enabled boolean) returns boolean language sql security invoker set search_path=pg_catalog as $fn$select grillad_private.connect_pair_set(p_link,p_zipple_hash,p_operator,p_proof,p_enabled)$fn$;
create function public.grillad_connect_pair_check(p_hash text,p_zipple_hash text) returns jsonb language sql stable security invoker set search_path=pg_catalog as $fn$select grillad_private.connect_pair_check(p_hash,p_zipple_hash)$fn$;
revoke all on function grillad_private.connect_pair_set(uuid,text,uuid,text,boolean),public.grillad_connect_pair_set(uuid,text,uuid,text,boolean),grillad_private.connect_pair_check(text,text),public.grillad_connect_pair_check(text,text) from public,anon,authenticated;
grant execute on function grillad_private.connect_pair_set(uuid,text,uuid,text,boolean),public.grillad_connect_pair_set(uuid,text,uuid,text,boolean),grillad_private.connect_pair_check(text,text),public.grillad_connect_pair_check(text,text) to service_role;
commit;
