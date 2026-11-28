-- Disposable candidate: durable in-app alerts, no claim of external dispatch.
begin;
create table public.sec_activity_notifications(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,site_id uuid not null,user_id uuid not null references auth.users(id),
 source text not null check(source in ('support','shift','safety','fire','warning','alarm')),
 source_id uuid not null,event_type text not null,created_at timestamptz not null default now(),read_at timestamptz,
 unique(user_id,source,source_id,event_type),foreign key(organization_id,site_id) references public.sec_sites(organization_id,id)
);
alter table public.sec_activity_notifications enable row level security;
revoke all on public.sec_activity_notifications from public,anon,authenticated;
grant select on public.sec_activity_notifications to authenticated;
create policy activity_read on public.sec_activity_notifications for select to authenticated using(user_id=auth.uid() and sec_private.field_role(organization_id,site_id) in ('owner','manager','operator'));
create index sec_activity_scope on public.sec_activity_notifications(organization_id,site_id,user_id,created_at desc);
create function sec_private.activity_notify() returns trigger language plpgsql security definer set search_path=pg_catalog as $f$
declare audience uuid;kind text;event_name text;source_id uuid;org uuid;site uuid;
begin
 org:=new.organization_id;site:=new.site_id;source_id:=new.id;
 if TG_TABLE_NAME='sec_support_events' then
  kind:='support';event_name:=new.operation;
  select case when c.requester_id=new.actor_id then c.agent_id else c.requester_id end into audience from public.sec_support_cases c where c.id=new.case_id and c.organization_id=org and c.site_id=site;
 elsif TG_TABLE_NAME='sec_shifts' then
  kind:='shift';event_name:=new.state;audience:=new.agent_id;
  if TG_OP='UPDATE' then if old.state=new.state then return new;end if;end if;
 elsif TG_TABLE_NAME='sec_internal_safety' then
  kind:='safety';event_name:=new.state;
  if TG_OP='UPDATE' then if old.state=new.state then return new;end if;audience:=new.reporter_id;end if;
 elsif TG_TABLE_NAME='sec_fire_events' then
  kind:='fire';event_name:=new.source_state;
 elsif TG_TABLE_NAME='sec_observation_alerts' then
  kind:='warning';event_name:=new.kind;
 else return new;end if;
 insert into public.sec_activity_notifications(organization_id,site_id,user_id,source,source_id,event_type)
 select org,site,m.user_id,kind,source_id,event_name
 from public.sec_memberships m join public.sec_site_memberships sm using(organization_id,user_id)
 join public.sec_sites s on s.id=sm.site_id and s.organization_id=sm.organization_id
 join public.sec_organizations o on o.id=s.organization_id
 where m.organization_id=org and sm.site_id=site and m.active and sm.active and s.active and o.active and m.role in ('owner','manager','operator')
 and ((audience is not null and m.user_id=audience) or (kind='support' and event_name='transfer' and exists(select 1 from public.sec_support_cases c where c.id=(to_jsonb(new)->>'case_id')::uuid and c.organization_id=org and c.site_id=site and c.agent_id=m.user_id)) or (audience is null and kind in ('safety','fire','warning') and m.role in ('owner','manager')))
 on conflict do nothing;
 return new;
end $f$;
revoke all on function sec_private.activity_notify() from public,anon,authenticated;
create trigger activity_support after insert on public.sec_support_events for each row execute function sec_private.activity_notify();
create trigger activity_shift after insert or update of state on public.sec_shifts for each row execute function sec_private.activity_notify();
create trigger activity_safety after insert or update of state on public.sec_internal_safety for each row execute function sec_private.activity_notify();
create trigger activity_fire after insert on public.sec_fire_events for each row execute function sec_private.activity_notify();
create trigger activity_warning after insert on public.sec_observation_alerts for each row execute function sec_private.activity_notify();
create function sec_private.read_activity(p_org uuid,p_site uuid,p_id uuid) returns jsonb language plpgsql security definer set search_path=pg_catalog as $f$
declare n public.sec_activity_notifications%rowtype;
begin
 if coalesce(sec_private.field_role(p_org,p_site),'') not in ('owner','manager','operator') then raise exception 'denied' using errcode='42501';end if;
 update public.sec_activity_notifications set read_at=coalesce(read_at,now()) where id=p_id and organization_id=p_org and site_id=p_site and user_id=auth.uid() returning * into n;
 if not found then raise exception 'notification denied' using errcode='42501';end if;
 return to_jsonb(n);
end $f$;
revoke all on function sec_private.read_activity(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function sec_private.read_activity(uuid,uuid,uuid) to authenticated;
create function public.sec_read_activity(p_org uuid,p_site uuid,p_id uuid) returns jsonb language sql security invoker set search_path=pg_catalog as $r$select sec_private.read_activity(p_org,p_site,p_id)$r$;
revoke all on function public.sec_read_activity(uuid,uuid,uuid) from public,anon;
grant execute on function public.sec_read_activity(uuid,uuid,uuid) to authenticated;

-- External delivery intent only: no provider call, no destination or sensitive payload.
create table sec_private.activity_channel_preferences(
 organization_id uuid not null,site_id uuid not null,user_id uuid not null references auth.users(id),
 channel text not null check(channel in ('fcm','web_push','sms','whatsapp','email')),
 enabled boolean not null default false,updated_at timestamptz not null default now(),
 primary key(organization_id,site_id,user_id,channel),
 foreign key(organization_id,site_id,user_id) references public.sec_site_memberships(organization_id,site_id,user_id)
);
create table sec_private.activity_delivery_intents(
 notification_id uuid not null references public.sec_activity_notifications(id) on delete cascade,
 channel text not null check(channel in ('fcm','web_push','sms','whatsapp','email')),
 state text not null default 'pending' check(state in ('pending','cancelled')),
 created_at timestamptz not null default now(),expires_at timestamptz not null,
 primary key(notification_id,channel),check(expires_at>created_at)
);
revoke all on sec_private.activity_channel_preferences,sec_private.activity_delivery_intents from public,anon,authenticated;
create function sec_private.set_activity_channel(p_org uuid,p_site uuid,p_channel text,p_enabled boolean) returns jsonb
 language plpgsql security definer set search_path=pg_catalog as $f$
begin
 if coalesce(sec_private.field_role(p_org,p_site),'') not in ('owner','manager','operator') then raise exception 'denied' using errcode='42501';end if;
 if p_channel is null or p_channel not in ('fcm','web_push','sms','whatsapp','email') or p_enabled is null then raise exception 'invalid channel' using errcode='22023';end if;
 -- Serialize consent changes and enqueue per recipient/site, including first opt-in.
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':'||p_site::text||':'||auth.uid()::text,26));
 insert into sec_private.activity_channel_preferences(organization_id,site_id,user_id,channel,enabled)
 values(p_org,p_site,auth.uid(),p_channel,p_enabled)
 on conflict(organization_id,site_id,user_id,channel) do update set enabled=excluded.enabled,updated_at=now();
 if not p_enabled then
  update sec_private.activity_delivery_intents d set state='cancelled' from public.sec_activity_notifications n
   where d.notification_id=n.id and n.organization_id=p_org and n.site_id=p_site and n.user_id=auth.uid() and d.channel=p_channel and d.state='pending';
 end if;
 return jsonb_build_object('organization_id',p_org,'site_id',p_site,'user_id',auth.uid(),'channel',p_channel,'enabled',p_enabled);
end $f$;
revoke all on function sec_private.set_activity_channel(uuid,uuid,text,boolean) from public,anon,authenticated;
grant execute on function sec_private.set_activity_channel(uuid,uuid,text,boolean) to authenticated;
create function public.sec_set_activity_channel(p_org uuid,p_site uuid,p_channel text,p_enabled boolean) returns jsonb
 language sql security invoker set search_path=pg_catalog as $f$select sec_private.set_activity_channel(p_org,p_site,p_channel,p_enabled)$f$;
revoke all on function public.sec_set_activity_channel(uuid,uuid,text,boolean) from public,anon;
grant execute on function public.sec_set_activity_channel(uuid,uuid,text,boolean) to authenticated;
create function sec_private.queue_activity_delivery() returns trigger language plpgsql security definer set search_path=pg_catalog as $f$
begin
 perform pg_advisory_xact_lock(hashtextextended(new.organization_id::text||':'||new.site_id::text||':'||new.user_id::text,26));
 insert into sec_private.activity_delivery_intents(notification_id,channel,expires_at)
 select new.id,p.channel,now()+interval '24 hours' from sec_private.activity_channel_preferences p
 where p.organization_id=new.organization_id and p.site_id=new.site_id and p.user_id=new.user_id and p.enabled
 on conflict do nothing;
 return new;
end $f$;
revoke all on function sec_private.queue_activity_delivery() from public,anon,authenticated;
create trigger activity_delivery_queue after insert on public.sec_activity_notifications for each row execute function sec_private.queue_activity_delivery();
-- Private view for future trusted dispatch adapter: expired, revoked or disabled intents are never eligible.
create view sec_private.activity_delivery_eligible with (security_invoker=true) as
 select d.notification_id,d.channel,d.created_at,d.expires_at,n.organization_id,n.site_id,n.user_id,n.source
 from sec_private.activity_delivery_intents d join public.sec_activity_notifications n on n.id=d.notification_id
 join sec_private.activity_channel_preferences p on p.organization_id=n.organization_id and p.site_id=n.site_id and p.user_id=n.user_id and p.channel=d.channel
 join public.sec_memberships m on m.organization_id=n.organization_id and m.user_id=n.user_id
 join public.sec_site_memberships sm on sm.organization_id=n.organization_id and sm.site_id=n.site_id and sm.user_id=n.user_id
 join public.sec_sites s on s.organization_id=n.organization_id and s.id=n.site_id
 join public.sec_organizations o on o.id=n.organization_id
 where d.state='pending' and d.expires_at>now() and p.enabled and m.active and sm.active and s.active and o.active and m.role in ('owner','manager','operator');
revoke all on sec_private.activity_delivery_eligible from public,anon,authenticated;
create function sec_private.activity_channels(p_org uuid,p_site uuid) returns jsonb language plpgsql stable security definer set search_path=pg_catalog as $f$
begin
 if coalesce(sec_private.field_role(p_org,p_site),'') not in ('owner','manager','operator') then raise exception 'denied' using errcode='42501';end if;
 return jsonb_build_object('organization_id',p_org,'site_id',p_site,'user_id',auth.uid(),'channels',(select jsonb_object_agg(c.channel,coalesce(p.enabled,false)) from unnest(array['fcm','web_push','sms','whatsapp','email']) c(channel) left join sec_private.activity_channel_preferences p on p.organization_id=p_org and p.site_id=p_site and p.user_id=auth.uid() and p.channel=c.channel));
end $f$;
revoke all on function sec_private.activity_channels(uuid,uuid) from public,anon,authenticated;
grant execute on function sec_private.activity_channels(uuid,uuid) to authenticated;
create function public.sec_activity_channels(p_org uuid,p_site uuid) returns jsonb language sql security invoker set search_path=pg_catalog as $r$select sec_private.activity_channels(p_org,p_site)$r$;
revoke all on function public.sec_activity_channels(uuid,uuid) from public,anon;
grant execute on function public.sec_activity_channels(uuid,uuid) to authenticated;
commit;
