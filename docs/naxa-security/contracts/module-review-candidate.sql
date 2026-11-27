-- Isolated review contract. Review is administrative disposition only, never authorization or execution.
begin;
alter table public.sec_module_requests drop constraint sec_module_requests_state_check;
alter table public.sec_module_requests add column reviewed_by uuid references auth.users(id), add column reviewed_at timestamptz, add column review_reason text;
alter table public.sec_module_requests add constraint sec_module_review_state check(
 (state='requested' and reviewed_by is null and reviewed_at is null and review_reason is null)
 or (state in ('reviewed','declined') and reviewed_by is not null and reviewed_by<>reporter_id and reviewed_at is not null and review_reason is not null and length(trim(review_reason)) between 1 and 500)
);
create function public.sec_module_review_queue(p_organization_id uuid,p_site_id uuid) returns setof public.sec_module_requests
language sql stable security definer set search_path=pg_catalog as $queue$
 select r.* from public.sec_module_requests r
 where r.organization_id=p_organization_id and r.site_id=p_site_id
 and r.kind in ('media','access','alarm','visitor','vehicle','compatibility','assignment','partner')
 and r.reporter_id<>auth.uid()
 and exists(select 1 from public.sec_memberships m join public.sec_site_memberships sm on sm.organization_id=m.organization_id and sm.user_id=m.user_id join public.sec_sites s on s.id=sm.site_id and s.organization_id=sm.organization_id join public.sec_organizations o on o.id=s.organization_id
 where m.organization_id=r.organization_id and sm.site_id=r.site_id and m.user_id=auth.uid() and m.role in ('owner','manager') and m.active and sm.active and s.active and o.active)
 order by r.created_at desc,r.id limit 100;
$queue$;
create function public.sec_review_module_request(p_request_id uuid,p_organization_id uuid,p_site_id uuid,p_decision text,p_reason text)
returns jsonb language plpgsql security definer set search_path=pg_catalog as $review$
declare r public.sec_module_requests%rowtype;
begin
 if auth.uid() is null or p_decision is null or p_decision not in ('reviewed','declined') or p_reason is null or length(trim(p_reason)) not between 1 and 500 or p_reason ~ '[[:cntrl:]]' then raise exception 'invalid review' using errcode='22023';end if;
 select q.* into r from public.sec_module_requests q where q.request_id=p_request_id and q.organization_id=p_organization_id and q.site_id=p_site_id
 and q.kind in ('media','access','alarm','visitor','vehicle','compatibility','assignment','partner') and q.reporter_id<>auth.uid()
 and exists(select 1 from public.sec_memberships m join public.sec_site_memberships sm on sm.organization_id=m.organization_id and sm.user_id=m.user_id join public.sec_sites s on s.id=sm.site_id and s.organization_id=sm.organization_id join public.sec_organizations o on o.id=s.organization_id
 where m.organization_id=q.organization_id and sm.site_id=q.site_id and m.user_id=auth.uid() and m.role in ('owner','manager') and m.active and sm.active and s.active and o.active)
 for update;
 if not found then raise exception 'review denied' using errcode='42501';end if;
 if r.state='requested' then update public.sec_module_requests set state=p_decision,reviewed_by=auth.uid(),reviewed_at=now(),review_reason=trim(p_reason) where id=r.id returning * into r;
 elsif r.state<>p_decision or r.reviewed_by<>auth.uid() or r.review_reason<>trim(p_reason) then raise exception 'review already recorded' using errcode='23505';end if;
 return to_jsonb(r);
end $review$;
revoke all on function public.sec_module_review_queue(uuid,uuid),public.sec_review_module_request(uuid,uuid,uuid,text,text) from public,anon;
grant execute on function public.sec_module_review_queue(uuid,uuid),public.sec_review_module_request(uuid,uuid,uuid,text,text) to authenticated;
commit;
