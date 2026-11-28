-- Candidate only; qualify against isolated Supabase before applying.
begin;
create schema if not exists naxa_control_private;
revoke all on schema naxa_control_private from public,anon,authenticated;
create table naxa_control_private.operators(
 user_id uuid primary key references auth.users(id) on delete restrict,
 role_code text not null check(role_code in ('administrator','finance','support')),
 active boolean not null default true,
 created_at timestamptz not null default now()
);
alter table naxa_control_private.operators enable row level security;
revoke all on naxa_control_private.operators from public,anon,authenticated;
create table naxa_control_private.action_log(
 id bigint generated always as identity primary key, actor uuid not null references auth.users(id),
 action_code text not null, target uuid not null, reason text not null,
 created_at timestamptz not null default now()
);
alter table naxa_control_private.action_log enable row level security;
revoke all on naxa_control_private.action_log from public,anon,authenticated;
create function naxa_control_private.operator_role() returns text
language sql stable security definer set search_path=pg_catalog as $$
 select o.role_code from naxa_control_private.operators o
 where o.user_id=auth.uid() and o.active and auth.jwt()->>'aal'='aal2'
 and exists(select 1 from auth.sessions s where s.user_id=o.user_id and s.id::text=auth.jwt()->>'session_id')
$$;
create function naxa_control_private.dashboard(p_app uuid default null) returns jsonb
language plpgsql stable security definer set search_path=pg_catalog as $$
declare r text:=naxa_control_private.operator_role(); result jsonb;
begin
 if r is null then raise exception 'CONTROL_ACCESS_DENIED' using errcode='42501';end if;
 if p_app is not null and not exists(select 1 from famille_core.applications where id=p_app) then raise exception 'CONTROL_UNKNOWN_APP' using errcode='22023';end if;
 result:=jsonb_build_object('role',r,'applications',coalesce((select jsonb_agg(to_jsonb(x) order by x.display_name) from (select id,code,display_name,status from famille_core.applications)x),'[]'::jsonb));
 if r='administrator' then
 result:=result||jsonb_build_object('accounts',coalesce((select jsonb_agg(to_jsonb(x)) from (select c.user_id,c.app_id,c.status,c.granted_at from famille_core.client_app_access c where p_app is null or c.app_id=p_app order by c.granted_at desc limit 200)x),'[]'::jsonb),'organizations',coalesce((select jsonb_agg(to_jsonb(x)) from (select distinct o.id,o.legal_name,o.status from famille_core.organizations o join famille_core.organization_apps a on a.organization_id=o.id where (p_app is null or a.app_id=p_app) and o.deleted_at is null order by o.legal_name limit 200)x),'[]'::jsonb));
 elsif r='finance' then
 result:=result||jsonb_build_object('plans',coalesce((select jsonb_agg(to_jsonb(x)) from (select id,app_id,name,amount_fcfa,billing_period,status from famille_core.plans where p_app is null or app_id=p_app order by name limit 200)x),'[]'::jsonb),'subscriptions',coalesce((select jsonb_agg(to_jsonb(x)) from (select id,organization_id,app_id,plan_id,status,starts_at,ends_at from famille_core.subscriptions where p_app is null or app_id=p_app order by created_at desc limit 200)x),'[]'::jsonb),'payments',coalesce((select jsonb_agg(to_jsonb(x)) from (select i.id,s.app_id,i.expected_amount_fcfa,i.channel,i.status,i.created_at from famille_core.payment_intents i join famille_core.subscriptions s on s.id=i.subscription_id where p_app is null or s.app_id=p_app order by i.created_at desc limit 200)x),'[]'::jsonb));
 elsif r='support' then
 result:=result||jsonb_build_object('tickets',coalesce((select jsonb_agg(to_jsonb(x)) from (select id,app_id,subject,description,status,created_at,updated_at from famille_core.support_tickets where deleted_at is null and (p_app is null or app_id=p_app) order by updated_at desc limit 200)x),'[]'::jsonb),'recoveries',coalesce((select jsonb_agg(to_jsonb(x)) from (select id,app_code,channel,status,created_at from famille_private.recovery_requests where p_app is null or app_code=(select code from famille_core.applications where id=p_app) order by created_at desc limit 200)x),'[]'::jsonb));
 end if;return result;
end $$;
create function naxa_control_private.ticket_transition(p_ticket uuid,p_expected text,p_next text,p_reason text) returns boolean
language plpgsql security definer set search_path=pg_catalog as $$
begin
 if naxa_control_private.operator_role() is distinct from 'support' then raise exception 'CONTROL_ACCESS_DENIED' using errcode='42501';end if;
 if length(coalesce(btrim(p_reason),'')) not between 10 and 300 or not coalesce((p_expected='open' and p_next='in_progress') or (p_expected='in_progress' and p_next in ('waiting_user','resolved')) or (p_expected='waiting_user' and p_next='in_progress') or (p_expected='resolved' and p_next='closed'),false) then raise exception 'CONTROL_INVALID_TRANSITION' using errcode='22023';end if;
 update famille_core.support_tickets set status=p_next,updated_at=now() where id=p_ticket and status=p_expected and deleted_at is null;
 if not found then raise exception 'CONTROL_STALE_TICKET' using errcode='40001';end if;
 insert into naxa_control_private.action_log(actor,action_code,target,reason) values(auth.uid(),'ticket.'||p_next,p_ticket,btrim(p_reason));
 return true;
end $$;
revoke all on all functions in schema naxa_control_private from public,anon,authenticated;
grant usage on schema naxa_control_private to authenticated;
grant execute on function naxa_control_private.dashboard(uuid),naxa_control_private.ticket_transition(uuid,text,text,text) to authenticated;
create function public.naxa_control_dashboard(p_app uuid default null) returns jsonb language sql stable security invoker set search_path=pg_catalog as $$select naxa_control_private.dashboard(p_app)$$;
create function public.naxa_control_ticket_transition(p_ticket uuid,p_expected text,p_next text,p_reason text) returns boolean language sql security invoker set search_path=pg_catalog as $$select naxa_control_private.ticket_transition(p_ticket,p_expected,p_next,p_reason)$$;
revoke all on function public.naxa_control_dashboard(uuid),public.naxa_control_ticket_transition(uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.naxa_control_dashboard(uuid),public.naxa_control_ticket_transition(uuid,text,text,text) to authenticated;
commit;
