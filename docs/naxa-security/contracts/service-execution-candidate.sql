-- SECURITY operational services in disposable PostgreSQL only. Never executes a physical command or a payment.
begin;
create schema if not exists sec_private;
revoke all on schema sec_private from public,anon,authenticated;
create table public.sec_preferences(
 organization_id uuid not null,site_id uuid not null,user_id uuid not null references auth.users(id),
 key text not null check(key in ('locale','push','sms','email','whatsapp')),
 value text not null,updated_at timestamptz not null default now(),
 primary key(organization_id,site_id,user_id,key),
 foreign key(organization_id,site_id) references public.sec_sites(organization_id,id),
 check((key='locale' and value in ('fr','en','ff-CM')) or (key<>'locale' and value in ('enabled','disabled')))
);
create table public.sec_service_register(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,site_id uuid not null,
 request_id uuid not null unique references public.sec_module_requests(request_id),reporter_id uuid not null references auth.users(id),
 reviewer_id uuid not null references auth.users(id),kind text not null check(kind in ('visitor','vehicle','assignment','partner','compatibility')),
 reference text not null,details jsonb not null,recorded_at timestamptz not null default now(),
 foreign key(organization_id,site_id) references public.sec_sites(organization_id,id),check(reporter_id<>reviewer_id)
);
create table public.sec_inbox(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,site_id uuid not null,user_id uuid not null references auth.users(id),
 request_id uuid not null references public.sec_module_requests(request_id),event_type text not null check(event_type in ('request_received','review_recorded')),
 created_at timestamptz not null default now(),read_at timestamptz,
 foreign key(organization_id,site_id) references public.sec_sites(organization_id,id),
 unique(request_id,event_type)
);
create table public.sec_support_messages(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,site_id uuid not null,
 request_id uuid not null references public.sec_module_requests(request_id),author_id uuid not null references auth.users(id),
 body text not null check(length(trim(body)) between 1 and 500 and body !~ '[[:cntrl:]]'),created_at timestamptz not null default now(),
 foreign key(organization_id,site_id) references public.sec_sites(organization_id,id)
);
create table public.sec_payment_receipts(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,site_id uuid not null,
 channel text not null check(channel in ('mobile_money','bank')),reference text not null check(reference ~ '^[A-Za-z0-9._-]{1,80}$'),
 amount_fcfa bigint not null check(amount_fcfa>0),provider_confirmed_at timestamptz not null,
 foreign key(organization_id,site_id) references public.sec_sites(organization_id,id),unique(channel,reference)
);
create table public.sec_device_observations(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,site_id uuid not null,device_id uuid not null,
 observed_at timestamptz not null,status text not null check(status in ('online','offline','fault')),
 metric text check(metric in ('temperature','humidity','water','co','gas')),value double precision,
 source_event_id uuid not null unique,received_at timestamptz not null default now(),
 foreign key(organization_id,site_id,device_id) references public.sec_devices(organization_id,site_id,id),
 check((metric is null and value is null) or (metric is not null and value is not null and value between -1000000 and 1000000)),
 check(metric is distinct from 'humidity' or value between 0 and 100),
 check(observed_at<=received_at)
);
create index sec_device_observations_scope on public.sec_device_observations(organization_id,site_id,device_id,observed_at desc);
create index sec_inbox_scope on public.sec_inbox(organization_id,site_id,user_id,created_at desc);
-- Server-owned effects. Only validated and RLS-authorized requests can reach these triggers.
create function sec_private.apply_request_effects() returns trigger language plpgsql security definer set search_path=pg_catalog as $effect$
begin
 if TG_OP='INSERT' then
  if new.kind='language' or new.kind='notification' then
   insert into public.sec_preferences(organization_id,site_id,user_id,key,value) values(new.organization_id,new.site_id,new.reporter_id,
    case when new.kind='language' then 'locale' else new.payload->>'channel' end,
    case when new.kind='language' then new.payload->>'locale' else new.payload->>'preference' end)
   on conflict(organization_id,site_id,user_id,key) do update set value=excluded.value,updated_at=now();
  end if;
  if new.kind='alarm' then
   insert into public.sec_incidents(organization_id,site_id,subject,priority,state,reporter_id,request_id)
   values(new.organization_id,new.site_id,new.payload->>'detail','P2','new',new.reporter_id,new.request_id);
  end if;
  if new.kind='support' then
   insert into public.sec_support_messages(organization_id,site_id,request_id,author_id,body)
   values(new.organization_id,new.site_id,new.request_id,new.reporter_id,new.payload->>'detail');
  end if;
  insert into public.sec_inbox(organization_id,site_id,user_id,request_id,event_type) values(new.organization_id,new.site_id,new.reporter_id,new.request_id,'request_received');
 elsif old.state='requested' and new.state in ('reviewed','declined') then
  if new.state='reviewed' and new.kind in ('visitor','vehicle','assignment','partner','compatibility') then
   insert into public.sec_service_register(organization_id,site_id,request_id,reporter_id,reviewer_id,kind,reference,details)
   values(new.organization_id,new.site_id,new.request_id,new.reporter_id,new.reviewed_by,new.kind,new.payload->>'reference',new.payload);
  end if;
  insert into public.sec_inbox(organization_id,site_id,user_id,request_id,event_type) values(new.organization_id,new.site_id,new.reporter_id,new.request_id,'review_recorded');
 end if;
 return new;
end $effect$;
revoke all on function sec_private.apply_request_effects() from public,anon,authenticated;
create trigger sec_request_effects after insert or update of state on public.sec_module_requests for each row execute function sec_private.apply_request_effects();
-- RLS and explicit grants. Provider receipts / telemetry are never writable by clients.
alter table public.sec_preferences enable row level security;
revoke all on public.sec_preferences from public,anon,authenticated;
grant select on public.sec_preferences to authenticated;
alter table public.sec_service_register enable row level security;
revoke all on public.sec_service_register from public,anon,authenticated;
grant select on public.sec_service_register to authenticated;
alter table public.sec_inbox enable row level security;
revoke all on public.sec_inbox from public,anon,authenticated;
grant select on public.sec_inbox to authenticated;
alter table public.sec_support_messages enable row level security;
revoke all on public.sec_support_messages from public,anon,authenticated;
grant select on public.sec_support_messages to authenticated;
alter table public.sec_payment_receipts enable row level security;
revoke all on public.sec_payment_receipts from public,anon,authenticated;
grant select on public.sec_payment_receipts to authenticated;
alter table public.sec_device_observations enable row level security;
revoke all on public.sec_device_observations from public,anon,authenticated;
grant select on public.sec_device_observations to authenticated;
create policy sec_preference_read on public.sec_preferences for select to authenticated using(user_id=(select auth.uid()) and exists(select 1 from public.sec_sites s where s.id=sec_preferences.site_id and s.organization_id=sec_preferences.organization_id));
create policy sec_register_read on public.sec_service_register for select to authenticated using(exists(select 1 from public.sec_sites s where s.id=sec_service_register.site_id and s.organization_id=sec_service_register.organization_id) and (reporter_id=(select auth.uid()) or exists(select 1 from public.sec_memberships m where m.organization_id=sec_service_register.organization_id and m.user_id=(select auth.uid()) and m.role in ('owner','manager') and m.active)));
create policy sec_inbox_read on public.sec_inbox for select to authenticated using(user_id=(select auth.uid()) and exists(select 1 from public.sec_sites s where s.id=sec_inbox.site_id and s.organization_id=sec_inbox.organization_id));
-- Client may read its own support thread; no operational manager can read a private ticket.
create policy sec_support_read on public.sec_support_messages for select to authenticated using(exists(select 1 from public.sec_module_requests r where r.request_id=sec_support_messages.request_id and r.organization_id=sec_support_messages.organization_id and r.site_id=sec_support_messages.site_id and r.kind='support' and r.reporter_id=(select auth.uid())));
grant insert(id,organization_id,site_id,request_id,author_id,body) on public.sec_support_messages to authenticated;
create policy sec_support_reply on public.sec_support_messages for insert to authenticated with check(author_id=(select auth.uid()) and exists(select 1 from public.sec_module_requests r where r.request_id=sec_support_messages.request_id and r.organization_id=sec_support_messages.organization_id and r.site_id=sec_support_messages.site_id and r.kind='support' and r.reporter_id=(select auth.uid())));
create policy sec_payment_read on public.sec_payment_receipts for select to authenticated using(exists(select 1 from public.sec_sites s where s.id=sec_payment_receipts.site_id and s.organization_id=sec_payment_receipts.organization_id) and exists(select 1 from public.sec_memberships m where m.organization_id=sec_payment_receipts.organization_id and m.user_id=(select auth.uid()) and m.role in ('owner','manager') and m.active));
create policy sec_observation_read on public.sec_device_observations for select to authenticated using(exists(select 1 from public.sec_sites s where s.id=sec_device_observations.site_id and s.organization_id=sec_device_observations.organization_id));
-- Read acknowledgement uses server time only, not an arbitrary timestamp supplied by a client.
create function sec_private.read_inbox(p_id uuid,p_org uuid,p_site uuid) returns jsonb language plpgsql security definer set search_path=pg_catalog as $ack$
declare row public.sec_inbox%rowtype;
begin
 update public.sec_inbox i set read_at=coalesce(i.read_at,now()) where i.id=p_id and i.organization_id=p_org and i.site_id=p_site and i.user_id=auth.uid()
 and exists(select 1 from public.sec_memberships m join public.sec_site_memberships sm on sm.organization_id=m.organization_id and sm.user_id=m.user_id join public.sec_sites s on s.id=sm.site_id and s.organization_id=sm.organization_id join public.sec_organizations o on o.id=s.organization_id where m.organization_id=i.organization_id and sm.site_id=i.site_id and m.user_id=auth.uid() and m.active and sm.active and s.active and o.active) returning * into row;
 if not found then raise exception 'inbox denied' using errcode='42501';end if;
 return to_jsonb(row);
end $ack$;
revoke all on function sec_private.read_inbox(uuid,uuid,uuid) from public,anon,authenticated;
grant usage on schema sec_private to authenticated;
grant execute on function sec_private.read_inbox(uuid,uuid,uuid) to authenticated;
create function public.sec_read_inbox(p_id uuid,p_org uuid,p_site uuid) returns jsonb language sql security invoker set search_path=pg_catalog as $rpc$select sec_private.read_inbox(p_id,p_org,p_site)$rpc$;
revoke all on function public.sec_read_inbox(uuid,uuid,uuid) from public,anon;
grant execute on function public.sec_read_inbox(uuid,uuid,uuid) to authenticated;
commit;
