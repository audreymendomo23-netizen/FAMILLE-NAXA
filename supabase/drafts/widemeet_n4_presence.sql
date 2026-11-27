-- Isolated candidate: trusted SFU observations, not continuous attendance proof.
begin;
create table public.wm_presence_samples(
 id uuid primary key,room_id uuid not null references public.wm_rooms(id),
 observed_at timestamptz not null default clock_timestamp(),observed uuid[] not null,
 check(cardinality(observed)<=100)
);
create index wm_presence_room_time on public.wm_presence_samples(room_id,observed_at);
alter table public.wm_presence_samples enable row level security;
revoke all on public.wm_presence_samples from public,anon,authenticated;
grant select,insert on public.wm_presence_samples to service_role;
create function public.wm_presence_record(p_room uuid,p_sample uuid,p_accounts uuid[])
returns boolean language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare r public.wm_rooms%rowtype;members uuid[];t timestamptz:=clock_timestamp();
begin
 if p_sample is null or p_accounts is null or cardinality(p_accounts)>100 then return false;end if;
 select * into r from public.wm_rooms where id=p_room for update;
 if not found or r.state->>'status'<>'open' or (r.state->>'endMs')::bigint<=floor(extract(epoch from t)*1000)::bigint then return false;end if;
 if exists(select 1 from public.wm_presence_samples where room_id=p_room and observed_at>t-interval '500 milliseconds') then return false;end if;
 select coalesce(array_agg(distinct a.id order by a.id),'{}'::uuid[]) into members
 from public.wm_accounts a where a.enabled and not a.password_change_required and a.id=any(p_accounts) and (exists(select 1 from public.wm_memberships m where m.workspace_id=r.workspace_id and m.account_id=a.id and m.enabled) or public.wm_external_guest_valid(r.id,a.id))
 and exists(select 1 from jsonb_array_elements(r.state->'participants') p where p->>'memberId'=a.id::text and p->>'response'='accepted' and p->>'excluded'='false'
 and (r.state->>'lobbyRequired' is distinct from 'true' or a.id=r.host_id or p->>'lobbyStatus'='admitted'));
 insert into public.wm_presence_samples(id,room_id,observed_at,observed) values(p_sample,p_room,t,members) on conflict do nothing;
 return found;
end $wm$;
revoke all on function public.wm_presence_record(uuid,uuid,uuid[]) from public,anon,authenticated;
grant execute on function public.wm_presence_record(uuid,uuid,uuid[]) to service_role;
create function public.wm_presence_report(p_hash text,p_room uuid)
returns jsonb language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare s record;r public.wm_rooms%rowtype;role_name text;host boolean;report jsonb;
begin
 select * into s from public.wm_session_context(p_hash);
 if not found or s.password_change_required then return null;end if;
 select role into role_name from public.wm_memberships where account_id=s.account_id and workspace_id=s.workspace_id and enabled;
 if not found then return null;end if;
 select * into r from public.wm_rooms where id=p_room and workspace_id=s.workspace_id and state->>'status'='ended';
 if not found or not exists(select 1 from public.wm_minutes_eligibility e where e.room_id=p_room and e.retain_until>clock_timestamp()) then return null;end if;
 host:=r.host_id=s.account_id and role_name in ('owner','promoteur','manager');
 if not host and not exists(select 1 from jsonb_array_elements(r.state->'participants') p where p->>'memberId'=s.account_id::text and p->>'response'='accepted' and p->>'excluded'='false' and (r.state->>'lobbyRequired' is distinct from 'true' or p->>'lobbyStatus'='admitted')) then return null;end if;
 with samples as(
  select observed_at,observed,lead(observed_at) over(order by observed_at,id) as next_at,lead(observed) over(order by observed_at,id) as next_members from public.wm_presence_samples where room_id=p_room
 ), intervals as(
  select *,floor(extract(epoch from(next_at-observed_at))*1000)::bigint as gap_ms from samples
 ), members as(
  select (p->>'memberId')::uuid as mid,p->>'response' as response,(p->>'excluded')::boolean as excluded from jsonb_array_elements(r.state->'participants') p where host or p->>'memberId'=s.account_id::text
 ), report_rows as(
  select m.mid as member_id,a.display_name,m.response,m.excluded,
   (select count(*) from samples x where m.mid=any(x.observed)) as samples_seen,
   (select min(observed_at) from samples x where m.mid=any(x.observed)) as first_seen,
   (select max(observed_at) from samples x where m.mid=any(x.observed)) as last_seen,
   coalesce((select sum(gap_ms) from intervals x where x.gap_ms between 1 and 10000 and m.mid=any(x.observed) and m.mid=any(x.next_members)),0)::bigint as estimated_ms
  from members m join public.wm_accounts a on a.id=m.mid
 )
 select jsonb_build_object('room_id',p_room,'basis','sfu_samples_not_continuous_presence','samples',(select count(*) from samples),
 'coverage_ms',coalesce((select sum(gap_ms) from intervals where gap_ms between 1 and 10000),0),
 'rows',coalesce((select jsonb_agg(to_jsonb(q)||jsonb_build_object('attendance',case when q.samples_seen>0 then 'observed' else 'unknown' end) order by q.display_name,q.member_id) from report_rows q),'[]'::jsonb))
 into report;return report;
end $wm$;
revoke all on function public.wm_presence_report(text,uuid) from public,anon,authenticated;
grant execute on function public.wm_presence_report(text,uuid) to service_role;
commit;
