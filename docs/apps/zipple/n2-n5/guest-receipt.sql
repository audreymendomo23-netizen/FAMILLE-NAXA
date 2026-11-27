begin;
-- Only the original unexpired guest token may read its own fully settled receipt.
-- The read-only receipt remains available after table closure, not the menu or order mutations.
create function public.zp_guest_receipt(p_guest_hash text,p_order uuid) returns jsonb
language plpgsql stable security invoker set search_path=pg_catalog,public as $$
declare o public.zp_orders;r public.zp_cash_receipts;s public.zp_credit_sales;site_name text;
 paid bigint;refund bigint:=0;credit_note bigint:=0;methods jsonb;settled_at timestamptz;
begin
 select x.* into o from public.zp_orders x join public.zp_guest_sessions g on g.id=x.guest_id and g.org_id=x.org_id and g.site_id=x.site_id
 join public.zp_sites si on si.id=x.site_id and si.org_id=x.org_id
 join public.zp_organizations org on org.id=x.org_id
 where x.id=p_order and g.token_hash=p_guest_hash and g.expires_at>now() and si.active and org.active and public.zp_operational_plan(x.org_id) is not null;
 if o.id is null then raise exception 'DENIED';end if;
 select * into r from public.zp_cash_receipts where order_id=o.id and org_id=o.org_id and site_id=o.site_id;
 if o.status='cancelled' or r.id is null or public.zp_credit_status(o.id)<>'paid' then return jsonb_build_object('available',false);end if;
 select name into site_name from public.zp_sites where id=o.site_id and org_id=o.org_id;
 if r.method='credit' then
   select * into s from public.zp_credit_sales where receipt_id=r.id and org_id=o.org_id and site_id=o.site_id;
   select coalesce(sum(amount_xaf),0),max(created_at) into paid,settled_at from public.zp_credit_payments where sale_id=s.id and org_id=o.org_id and site_id=o.site_id;
   if paid<=0 or paid is distinct from s.paid_xaf then return jsonb_build_object('available',false);end if;
   refund:=s.refunded_xaf;credit_note:=s.credit_note_xaf;
   select coalesce(jsonb_agg(to_jsonb(m) order by m.method),'[]') into methods from (select method,sum(amount_xaf) amount_xaf from public.zp_credit_payments where sale_id=s.id and org_id=o.org_id and site_id=o.site_id group by method)m;
 else
   paid:=r.amount_xaf;settled_at:=r.created_at;
   select coalesce(sum(amount_xaf),0) into refund from public.zp_cash_outflows where kind='refund' and source_id=r.id and org_id=o.org_id and site_id=o.site_id;
   if r.method='mixed' then
      select coalesce(jsonb_agg(to_jsonb(m) order by m.method),'[]') into methods from (select method,sum(amount_xaf) amount_xaf from public.zp_cash_tenders where receipt_id=r.id and org_id=o.org_id and site_id=o.site_id group by method)m;
   else methods:=jsonb_build_array(jsonb_build_object('method',r.method,'amount_xaf',paid));end if;
 end if;
 return jsonb_build_object('available',true,'receipt_id',r.id,'order_number',o.service_number,'site_name',site_name,'settled_at',settled_at,
 'total_xaf',o.total_xaf,'paid_xaf',paid,'refunded_xaf',refund,'credit_note_xaf',credit_note,'methods',methods,'lines',
 coalesce((select jsonb_agg(jsonb_build_object('name',l->>'name','qty',l->'qty','price_xaf',l->'price_xaf') order by ord) from jsonb_array_elements(o.commercial_lines) with ordinality a(l,ord)),'[]'::jsonb));
end $$;
revoke all on function public.zp_guest_receipt(text,uuid) from public,anon,authenticated;
grant execute on function public.zp_guest_receipt(text,uuid) to service_role;
commit;
