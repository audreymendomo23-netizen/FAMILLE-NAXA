-- Isolated candidate. Request is not authorization, payment, device action or alarm.
begin;
create table public.sec_module_requests (
 id uuid primary key default gen_random_uuid(),organization_id uuid not null,site_id uuid not null,
 reporter_id uuid not null references auth.users(id),request_id uuid not null unique,
 kind text not null check(kind in ('media','access','alarm','visitor','vehicle','sos','compatibility','assignment','payment','support','notification','language','admin','evidence','backup','partner')),
 payload jsonb not null check(jsonb_typeof(payload)='object' and octet_length(payload::text)<=4096),
 state text not null default 'requested' check(state='requested'),created_at timestamptz not null default now(),
 foreign key(organization_id,site_id) references public.sec_sites(organization_id,id)
);
create function public.sec_valid_module_request(k text,p jsonb) returns boolean language plpgsql immutable set search_path=pg_catalog as $validate$
declare allowed text[]; d numeric;
begin
 if jsonb_typeof(p) is distinct from 'object' then return false;end if;
 allowed:=case k when 'media' then array['reference','purpose','consent','media'] when 'access' then array['reference','purpose','duration_minutes'] when 'visitor' then array['reference','purpose','duration_minutes'] when 'vehicle' then array['reference','purpose','duration_minutes'] when 'assignment' then array['reference','purpose','duration_minutes'] when 'alarm' then array['reference','kind','detail'] when 'sos' then array['reference','detail'] when 'compatibility' then array['reference','firmware','protocol'] when 'payment' then array['reference','amount_fcfa','channel'] when 'support' then array['category','detail'] when 'notification' then array['channel','preference'] when 'language' then array['locale'] when 'admin' then array['reference','purpose'] when 'evidence' then array['reference','digest'] when 'backup' then array['reference','purpose'] when 'partner' then array['reference','purpose'] else null end;
 if allowed is null or not(p ?& allowed) or exists(select 1 from jsonb_object_keys(p) a(key) where not(a.key=any(allowed))) then return false;end if;
 if exists(select 1 from jsonb_each(p) a where a.key not in ('duration_minutes','amount_fcfa') and (jsonb_typeof(a.value)<>'string' or length(trim(a.value#>>'{}')) not between 1 and 500 or (a.value#>>'{}') ~ '[[:cntrl:]]')) then return false;end if;
 if p ? 'reference' and (p->>'reference') !~ '^[A-Za-z0-9._-]{1,80}$' then return false;end if;
 if p ? 'purpose' and length(p->>'purpose')>120 then return false;end if;
 if p ? 'duration_minutes' then if jsonb_typeof(p->'duration_minutes')<>'number' then return false;end if;d:=(p->>'duration_minutes')::numeric;if d<>trunc(d) or d not between 1 and 1440 then return false;end if;end if;
 if k='media' then return p->>'consent'='yes' and p->>'media' in ('video','audio');end if;
 if k='alarm' then return p->>'kind' in ('intrusion','sabotage','fault');end if;
 if k='compatibility' then return length(p->>'firmware')<=80 and p->>'protocol' in ('onvif','rtsp','vendor_api','other');end if;
 if k='payment' then if jsonb_typeof(p->'amount_fcfa')<>'number' then return false;end if;d:=(p->>'amount_fcfa')::numeric;return d=trunc(d) and d between 1 and 100000000 and p->>'channel' in ('mobile_money','bank');end if;
 if k='support' then return p->>'category' in ('account','technical','billing','privacy','other');end if;
 if k='notification' then return p->>'channel' in ('push','sms','email','whatsapp') and p->>'preference' in ('enabled','disabled');end if;
 if k='language' then return p->>'locale' in ('fr','en','ff-CM');end if;
 if k='evidence' then return p->>'digest' ~ '^[a-f0-9]{64}$';end if;
 return true;
end $validate$;
alter table public.sec_module_requests add constraint sec_module_payload_check check(public.sec_valid_module_request(kind,payload) is true);
revoke all on function public.sec_valid_module_request(text,jsonb) from public,anon;
grant execute on function public.sec_valid_module_request(text,jsonb) to authenticated;
alter table public.sec_module_requests enable row level security;
revoke all on public.sec_module_requests from public,anon,authenticated;
grant select on public.sec_module_requests to authenticated;
grant insert(organization_id,site_id,reporter_id,request_id,kind,payload) on public.sec_module_requests to authenticated;
create policy sec_module_read on public.sec_module_requests for select to authenticated using(reporter_id=(select auth.uid()) and exists(select 1 from public.sec_sites s where s.id=sec_module_requests.site_id and s.organization_id=sec_module_requests.organization_id));
create policy sec_module_insert on public.sec_module_requests for insert to authenticated with check(reporter_id=(select auth.uid()) and state='requested' and exists(select 1 from public.sec_sites s where s.id=sec_module_requests.site_id and s.organization_id=sec_module_requests.organization_id) and exists(select 1 from public.sec_memberships m where m.organization_id=sec_module_requests.organization_id and m.user_id=(select auth.uid()) and m.role in ('owner','manager','operator') and m.active) and (kind not in ('admin','backup','payment','partner') or exists(select 1 from public.sec_memberships m where m.organization_id=sec_module_requests.organization_id and m.user_id=(select auth.uid()) and m.role in ('owner','manager') and m.active)));
commit;
