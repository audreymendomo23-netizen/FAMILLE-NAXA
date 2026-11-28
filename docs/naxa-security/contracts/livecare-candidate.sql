-- Candidate: Livecare software support with explicitly provisioned, site-bound agents.
begin;
create table sec_private.support_agents(
 organization_id uuid not null,site_id uuid not null,user_id uuid not null references auth.users(id),active boolean not null default true,
 primary key(organization_id,site_id,user_id),foreign key(organization_id,site_id,user_id) references public.sec_site_memberships(organization_id,site_id,user_id)
);
revoke all on sec_private.support_agents from public,anon,authenticated;
create table public.sec_support_cases(
 id uuid primary key references public.sec_module_requests(request_id),organization_id uuid not null,site_id uuid not null,
 requester_id uuid not null references auth.users(id),agent_id uuid references auth.users(id),
 category text not null check(category in ('account','technical','billing','privacy','other')),
 state text not null default 'open' check(state in ('open','assigned','waiting_customer','resolved','closed')),
 priority text not null default 'normal' check(priority in ('normal','high')),
 created_at timestamptz not null default now(),due_at timestamptz not null,first_reply_at timestamptz,resolved_at timestamptz,
 rating int check(rating between 1 and 5),
 foreign key(organization_id,site_id) references public.sec_sites(organization_id,id),
 check(agent_id is null or agent_id<>requester_id)
);
create table public.sec_support_events(
 id uuid primary key,organization_id uuid not null,site_id uuid not null,case_id uuid not null references public.sec_support_cases(id),
 actor_id uuid not null references auth.users(id),operation text not null,detail_hash text not null,receipt jsonb not null,created_at timestamptz not null default now(),
 foreign key(organization_id,site_id) references public.sec_sites(organization_id,id)
);
alter table public.sec_support_cases enable row level security;
alter table public.sec_support_events enable row level security;
revoke all on public.sec_support_cases,public.sec_support_events from public,anon,authenticated;
grant select on public.sec_support_cases,public.sec_support_events to authenticated;
create function sec_private.is_support_agent(p_org uuid,p_site uuid) returns boolean language sql stable security definer set search_path=pg_catalog as $f$
 select exists(select 1 from sec_private.support_agents a where a.organization_id=p_org and a.site_id=p_site and a.user_id=auth.uid() and a.active and sec_private.field_role(p_org,p_site) in ('owner','manager','operator'))
$f$;
revoke all on function sec_private.is_support_agent(uuid,uuid) from public,anon,authenticated;
grant execute on function sec_private.is_support_agent(uuid,uuid) to authenticated;
create policy support_case_read on public.sec_support_cases for select to authenticated using(sec_private.field_role(organization_id,site_id) is not null and (requester_id=auth.uid() or (sec_private.is_support_agent(organization_id,site_id) and (agent_id=auth.uid() or (agent_id is null and state='open')))));
create policy support_event_read on public.sec_support_events for select to authenticated using(exists(select 1 from public.sec_support_cases c where c.id=case_id and c.organization_id=sec_support_events.organization_id and c.site_id=sec_support_events.site_id and (c.requester_id=auth.uid() or c.agent_id=auth.uid())));
create policy support_assigned_agent_read on public.sec_support_messages for select to authenticated using(sec_private.is_support_agent(organization_id,site_id) and exists(select 1 from public.sec_support_cases c where c.id=request_id and c.organization_id=sec_support_messages.organization_id and c.site_id=sec_support_messages.site_id and c.agent_id=auth.uid()));
create function sec_private.create_support_case() returns trigger language plpgsql security definer set search_path=pg_catalog as $f$
begin
 if new.kind='support' then
  insert into public.sec_support_cases(id,organization_id,site_id,requester_id,category,due_at) values(new.request_id,new.organization_id,new.site_id,new.reporter_id,new.payload->>'category',now()+interval '24 hours');
 end if;
 return new;
end $f$;
revoke all on function sec_private.create_support_case() from public,anon,authenticated;
create trigger sec_support_case_create after insert on public.sec_module_requests for each row execute function sec_private.create_support_case();
-- Prior requester message API remains backward compatible but cannot append after closure.
create function sec_private.guard_support_message() returns trigger language plpgsql security definer set search_path=pg_catalog as $f$
declare c public.sec_support_cases%rowtype;
begin
 select * into c from public.sec_support_cases where id=new.request_id for update;
 -- The earlier trigger inserts the initial message before creation of its case.
 if not found then
  if exists(select 1 from public.sec_module_requests r where r.request_id=new.request_id and r.kind='support' and r.reporter_id=new.author_id and r.organization_id=new.organization_id and r.site_id=new.site_id and r.payload->>'detail'=new.body)
  and not exists(select 1 from public.sec_support_messages m where m.request_id=new.request_id) then return new;end if;
  raise exception 'case missing' using errcode='42501';
 end if;
 if c.organization_id<>new.organization_id or c.site_id<>new.site_id or c.state in ('resolved','closed') or new.author_id not in (c.requester_id,coalesce(c.agent_id,c.requester_id)) then raise exception 'message denied' using errcode='42501';end if;
 if new.author_id=c.requester_id and c.state='waiting_customer' then update public.sec_support_cases set state='assigned' where id=c.id;end if;
 return new;
end $f$;
revoke all on function sec_private.guard_support_message() from public,anon,authenticated;
create trigger sec_support_message_guard before insert on public.sec_support_messages for each row execute function sec_private.guard_support_message();
create function sec_private.support_action(p_org uuid,p_site uuid,p_case uuid,p_event uuid,p_op text,p_detail jsonb) returns jsonb language plpgsql security definer set search_path=pg_catalog as $f$
declare c public.sec_support_cases%rowtype;old public.sec_support_events%rowtype;h text;out jsonb;body text;agent boolean;customer boolean;score integer;target_agent uuid;transfer_reason text;
begin
 if coalesce(sec_private.field_role(p_org,p_site),'') not in ('owner','manager','operator') or p_event is null or p_op is null or jsonb_typeof(p_detail) is distinct from 'object' or octet_length(p_detail::text)>2048 then raise exception 'denied' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_org::text||':'||p_site::text,392));
 perform pg_advisory_xact_lock(hashtextextended(p_event::text,7));
 select * into c from public.sec_support_cases where id=p_case and organization_id=p_org and site_id=p_site for update;
 if not found then raise exception 'case denied' using errcode='42501';end if;
 agent:=sec_private.is_support_agent(p_org,p_site);customer:=c.requester_id=auth.uid();
 h:=encode(sha256(convert_to(p_detail::text,'UTF8')),'hex');
 select * into old from public.sec_support_events where id=p_event;
 if found then
  if not coalesce(customer or (agent and (c.agent_id=auth.uid() or (p_op='transfer' and old.actor_id=auth.uid() and old.organization_id=p_org and old.site_id=p_site and old.case_id=p_case and old.operation='transfer'))),false) then raise exception 'case denied' using errcode='42501';end if;
  if old.actor_id<>auth.uid() or old.organization_id<>p_org or old.site_id<>p_site or old.case_id<>p_case or old.operation<>p_op or old.detail_hash<>h then raise exception 'event conflict' using errcode='23505';end if;
  return old.receipt;
 end if;
 if not coalesce(customer or (agent and (c.agent_id=auth.uid() or (c.agent_id is null and p_op='claim'))),false) then raise exception 'case denied' using errcode='42501';end if;
 if p_op='claim' and agent and not customer and c.state='open' and c.agent_id is null and p_detail='{}'::jsonb then
  update public.sec_support_cases set agent_id=auth.uid(),state='assigned' where id=c.id returning * into c;
 elsif p_op='reply' and agent and not customer and c.agent_id=auth.uid() and c.state in ('assigned','waiting_customer') and p_detail-'body'='{}'::jsonb then
  body:=trim(coalesce(p_detail->>'body',''));
  if length(body) not between 1 and 500 or body ~ '[[:cntrl:]]' then raise exception 'invalid reply' using errcode='22023';end if;
  insert into public.sec_support_messages(id,organization_id,site_id,request_id,author_id,body) values(p_event,p_org,p_site,c.id,auth.uid(),body);
  update public.sec_support_cases set state='waiting_customer',first_reply_at=coalesce(first_reply_at,now()) where id=c.id returning * into c;
 elsif p_op='customer_reply' and customer and c.state in ('open','assigned','waiting_customer') and p_detail-'body'='{}'::jsonb then
  body:=trim(coalesce(p_detail->>'body',''));
  if length(body) not between 1 and 500 or body ~ '[[:cntrl:]]' then raise exception 'invalid reply' using errcode='22023';end if;
  insert into public.sec_support_messages(id,organization_id,site_id,request_id,author_id,body) values(p_event,p_org,p_site,c.id,auth.uid(),body);
  select * into c from public.sec_support_cases where id=p_case;
 elsif p_op='transfer' and agent and c.agent_id=auth.uid() and c.state in ('assigned','waiting_customer') and p_detail-'agent_id'-'reason'='{}'::jsonb then
  target_agent:=(p_detail->>'agent_id')::uuid;transfer_reason:=trim(coalesce(p_detail->>'reason',''));
  if target_agent is null or target_agent in (c.requester_id,auth.uid()) or length(transfer_reason) not between 1 and 500 or transfer_reason ~ '[[:cntrl:]]' then raise exception 'invalid transfer' using errcode='22023';end if;
  if not exists(select 1 from sec_private.support_agents a join public.sec_site_memberships sm using(organization_id,site_id,user_id) join public.sec_memberships m using(organization_id,user_id) where a.organization_id=p_org and a.site_id=p_site and a.user_id=target_agent and a.active and sm.active and m.active and m.role in ('owner','manager','operator')) then raise exception 'recipient denied' using errcode='42501';end if;
  update public.sec_support_cases set agent_id=target_agent where id=c.id returning * into c;
 elsif p_op='escalate' and agent and c.agent_id=auth.uid() and c.state in ('assigned','waiting_customer') and p_detail='{}'::jsonb then
  update public.sec_support_cases set priority='high',due_at=least(due_at,now()+interval '4 hours') where id=c.id returning * into c;
 elsif p_op='resolve' and agent and c.agent_id=auth.uid() and c.state in ('assigned','waiting_customer') and p_detail='{}'::jsonb then
  update public.sec_support_cases set state='resolved',resolved_at=now() where id=c.id returning * into c;
 elsif p_op='reopen' and customer and c.state='resolved' and p_detail='{}'::jsonb then
  update public.sec_support_cases set state=case when exists(select 1 from sec_private.support_agents a join public.sec_site_memberships sm using(organization_id,site_id,user_id) join public.sec_memberships m using(organization_id,user_id) where a.organization_id=p_org and a.site_id=p_site and a.user_id=c.agent_id and a.active and sm.active and m.active and m.role in ('owner','manager','operator')) then 'assigned' else 'open' end,agent_id=case when exists(select 1 from sec_private.support_agents a join public.sec_site_memberships sm using(organization_id,site_id,user_id) join public.sec_memberships m using(organization_id,user_id) where a.organization_id=p_org and a.site_id=p_site and a.user_id=c.agent_id and a.active and sm.active and m.active and m.role in ('owner','manager','operator')) then c.agent_id else null end,resolved_at=null where id=c.id returning * into c;
 elsif p_op='close' and customer and c.state='resolved' and p_detail-'rating'='{}'::jsonb and jsonb_typeof(p_detail->'rating')='number' then
  score:=(p_detail->>'rating')::integer;
  if score not between 1 and 5 then raise exception 'invalid rating' using errcode='22023';end if;
  update public.sec_support_cases set state='closed',rating=score where id=c.id returning * into c;
 else raise exception 'invalid support action' using errcode='22023';end if;
 out:=jsonb_build_object('event_id',p_event,'organization_id',p_org,'site_id',p_site,'case_id',c.id,'actor_id',auth.uid(),'operation',p_op,'state',c.state,'priority',c.priority);
 if p_op='transfer' then out:=out||jsonb_build_object('agent_id',c.agent_id,'reason',transfer_reason);end if;
 insert into public.sec_support_events values(p_event,p_org,p_site,c.id,auth.uid(),p_op,h,out,now());
 return out;
end $f$;
revoke all on function sec_private.support_action(uuid,uuid,uuid,uuid,text,jsonb) from public,anon,authenticated;
grant execute on function sec_private.support_action(uuid,uuid,uuid,uuid,text,jsonb) to authenticated;
create function public.sec_support_action(p_org uuid,p_site uuid,p_case uuid,p_event uuid,p_op text,p_detail jsonb) returns jsonb language sql security invoker set search_path=pg_catalog as $r$select sec_private.support_action(p_org,p_site,p_case,p_event,p_op,p_detail)$r$;
revoke all on function public.sec_support_action(uuid,uuid,uuid,uuid,text,jsonb) from public,anon;
grant execute on function public.sec_support_action(uuid,uuid,uuid,uuid,text,jsonb) to authenticated;
commit;
