begin;
-- B4: enforce financial document balances and bind recurring payment to its due date.
create or replace function public.ns_create_management_record(
  p_record_id uuid,p_org_id uuid,p_site_id uuid,p_workstation_id uuid,
  p_record_type text,p_reference text,p_title text,p_counterparty text,
  p_amount_xaf bigint,p_paid_xaf bigint,p_due_at timestamptz,p_status text,
  p_metadata_json jsonb
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $naxa$
declare v_member uuid; v_record public.ns_management_records%rowtype; v_activity text; v_expected_type text;
begin
  v_member:=public.ns_current_member_id(p_org_id);
  if v_member is null or not public.ns_can_operate_site(p_org_id,p_site_id) then
    raise exception 'NAXA_MANAGEMENT_RECORD_FORBIDDEN';
  end if;
  if p_record_id is null
     or p_record_type not in (
       'quote','invoice','credit_note','refund_due','customer_receivable','purchase',
       'supplier','tax_estimate','business_goal','subscription_request','support_chat',
       'work_order','repair_order','service_order','appointment_waitlist',
       'staff_clock_in','staff_clock_out','staff_break_start','staff_break_end',
       'staff_commission','staff_advance','staff_bonus'
     )
     or length(trim(coalesce(p_reference,''))) not between 1 and 120
     or length(trim(coalesce(p_title,''))) not between 1 and 180
     or length(coalesce(p_counterparty,''))>180
     or p_amount_xaf is null or p_amount_xaf<0
     or p_paid_xaf is null or p_paid_xaf<0 or p_paid_xaf>p_amount_xaf
     or p_status not in (
       'draft','received','open','diagnostic','measurement','quote_pending',
       'waiting_customer','awaiting_approval','contacted','approved','waiting_parts',
       'fabrication','fitting','proof_ready','production','planning','shooting',
       'post_production','on_site','installation','ordered','partially_received',
       'in_progress','quality_check','ready','delivered','invoice_review','closed',
       'partial','paid','cancelled','pending_review','rejected','booked'
     )
     or jsonb_typeof(coalesce(p_metadata_json,'{}'::jsonb))<>'object'
     or octet_length(coalesce(p_metadata_json,'{}'::jsonb)::text)>4000 then
    raise exception 'NAXA_MANAGEMENT_RECORD_INVALID';
  end if;
  if p_workstation_id is not null and (
    not exists(select 1 from public.ns_workstations w
      where w.id=p_workstation_id and w.org_id=p_org_id and w.site_id=p_site_id and w.status='active')
    or not public.ns_can_operate_workstation(p_org_id,p_site_id,p_workstation_id)
  ) then raise exception 'NAXA_MANAGEMENT_RECORD_WORKSTATION_FORBIDDEN'; end if;
  v_activity:=coalesce(nullif(p_metadata_json->>'activity_profile',''),nullif(p_metadata_json->>'activity',''));
  if p_metadata_json ? 'fields' then
    v_expected_type:=case when v_activity in ('coiffure','beaute','nettoyage','domicile') then 'service_order' when v_activity in ('reparation','garage') then 'repair_order' when v_activity in ('couture','parfumerie','menuiserie','impression','photo_evenementiel','autre') then 'work_order' else null end;
    if v_expected_type is null or p_record_type<>v_expected_type or p_status<>'received' or not public.ns_activity_workflow_fields_valid(v_activity,p_metadata_json->'fields') then raise exception 'NAXA_ACTIVITY_WORKFLOW_CREATE_INVALID'; end if;
  end if;

  if p_record_type in ('invoice','refund_due','customer_receivable') and
    (p_amount_xaf<=0 or p_status is null or not (
      (p_paid_xaf=0 and p_status in ('draft','open')) or
      (p_paid_xaf>0 and p_paid_xaf<p_amount_xaf and p_status='partial') or
      (p_paid_xaf=p_amount_xaf and p_status='paid')
    )) then raise exception 'NAXA_FINANCIAL_INITIAL_BALANCE_INVALID'; end if;
  if p_record_type in ('quote','credit_note') and
    (p_amount_xaf<=0 or p_paid_xaf<>0 or p_status is null or p_status not in ('draft','open'))
    then raise exception 'NAXA_NON_PAYMENT_DOCUMENT_INVALID'; end if;
  if (p_record_type='appointment_waitlist' and p_status not in ('open','contacted'))
     or (p_record_type in ('staff_commission','staff_advance','staff_bonus') and p_status not in ('pending_review','draft'))
     or (p_record_type in ('staff_clock_in','staff_clock_out','staff_break_start','staff_break_end') and p_status<>'open')
     or (p_record_type='quote' and p_status not in ('draft','open'))
     or (p_record_type='purchase' and p_status not in ('draft','open')) then
    raise exception 'NAXA_MANAGEMENT_RECORD_INITIAL_STATUS_INVALID';
  end if;

  insert into public.ns_management_records(
    id,org_id,site_id,workstation_id,record_type,reference,title,counterparty,
    amount_xaf,paid_xaf,due_at,status,metadata_json,revision,created_by
  ) values (
    p_record_id,p_org_id,p_site_id,p_workstation_id,p_record_type,trim(p_reference),
    trim(p_title),trim(coalesce(p_counterparty,'')),p_amount_xaf,p_paid_xaf,
    p_due_at,p_status,coalesce(p_metadata_json,'{}'::jsonb),1,v_member
  ) returning * into v_record;

  insert into public.ns_management_record_events(
    id,org_id,site_id,record_id,from_status,to_status,reason,actor_member_id,revision,occurred_at
  ) values (
    gen_random_uuid(),p_org_id,p_site_id,p_record_id,'',p_status,
    'Création du dossier',v_member,1,now()
  );
  return jsonb_build_object('record_id',v_record.id,'record_type',v_record.record_type,
    'status',v_record.status,'revision',v_record.revision,'paid_xaf',v_record.paid_xaf,'amount_xaf',v_record.amount_xaf,'created',true);
end;
$naxa$;

create or replace function public.ns_transition_management_record(
  p_record_id uuid,p_org_id uuid,p_site_id uuid,p_workstation_id uuid,
  p_record_type text,p_from_status text,p_to_status text,p_reason text,
  p_expected_version integer,p_metadata_json_delta jsonb,p_transitioned_at timestamptz
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $naxa$
declare
  v_member uuid; v_record public.ns_management_records%rowtype;
  v_allowed boolean:=false; v_metadata jsonb; v_activity text; v_expected_type text;
  v_transfer public.ns_inventory_transfers%rowtype;
  v_paid bigint;
begin
  v_member:=public.ns_current_member_id(p_org_id);
  if v_member is null or not public.ns_can_operate_site(p_org_id,p_site_id) then
    raise exception 'NAXA_MANAGEMENT_TRANSITION_FORBIDDEN';
  end if;
  if p_record_id is null or p_expected_version is null or p_expected_version<1
     or length(trim(coalesce(p_reason,''))) not between 3 and 500
     or jsonb_typeof(coalesce(p_metadata_json_delta,'{}'::jsonb))<>'object' then
    raise exception 'NAXA_MANAGEMENT_TRANSITION_INVALID';
  end if;
  select * into v_record from public.ns_management_records
   where id=p_record_id and org_id=p_org_id and site_id=p_site_id
   for update;
  if not found or v_record.record_type<>p_record_type then
    raise exception 'NAXA_MANAGEMENT_RECORD_NOT_FOUND';
  end if;
  if p_record_type not in ('invoice','refund_due','customer_receivable','quote','credit_note') and v_record.status=p_to_status and v_record.revision>=p_expected_version then
    return jsonb_build_object('record_id',v_record.id,'status',v_record.status,
      'revision',v_record.revision,'idempotent',true);
  end if;
  if v_record.revision<>p_expected_version or v_record.status<>p_from_status then
    raise exception 'NAXA_MANAGEMENT_RECORD_VERSION_CONFLICT';
  end if;
  v_activity:=coalesce(nullif(v_record.metadata_json->>'activity_profile',''),nullif(v_record.metadata_json->>'activity',''));
  v_expected_type:=case when v_activity in ('coiffure','beaute','nettoyage','domicile') then 'service_order' when v_activity in ('reparation','garage') then 'repair_order' when v_activity in ('couture','parfumerie','menuiserie','impression','photo_evenementiel','autre') then 'work_order' else null end;


  if p_record_type='inventory_transfer' then
    select * into v_transfer from public.ns_inventory_transfers
      where id=p_record_id and org_id=p_org_id and source_site_id=p_site_id for update;
    if not found then raise exception 'NAXA_INVENTORY_TRANSFER_NOT_FOUND'; end if;
    v_allowed:=(p_from_status='open' and p_to_status in ('approved','rejected'))
      or (p_from_status='approved' and p_to_status='received' and v_transfer.status='received');
    if p_to_status='received' and v_transfer.status<>'received' then
      raise exception 'NAXA_INVENTORY_TRANSFER_RECEIVE_REQUIRES_COMPOSITE_ACTION';
    end if;
    if p_to_status in ('approved','rejected') and not public.ns_can_manage_org(p_org_id) then
      raise exception 'NAXA_INVENTORY_TRANSFER_APPROVAL_FORBIDDEN';
    end if;
    if v_transfer.status<>p_from_status and not (p_to_status='received' and v_transfer.status='received') then
      raise exception 'NAXA_INVENTORY_TRANSFER_VERSION_CONFLICT';
    end if;
    if v_transfer.status=p_to_status and p_to_status='received' then
      v_allowed:=true;
    else
      update public.ns_inventory_transfers
       set status=p_to_status,revision=revision+1,
           approved_by=case when p_to_status='approved' then v_member else approved_by end,
           approved_at=case when p_to_status='approved' then coalesce(p_transitioned_at,now()) else approved_at end,
           reason=trim(p_reason)
       where id=p_record_id and org_id=p_org_id and source_site_id=p_site_id
       returning * into v_transfer;
    end if;
  else
    v_allowed:=case p_record_type
      when 'quote' then (p_from_status in ('draft','open') and p_to_status in ('approved','rejected','cancelled'))
      when 'invoice' then (p_from_status in ('draft','open','partial') and p_to_status in ('partial','paid','cancelled'))
      when 'credit_note' then (p_from_status in ('draft','open') and p_to_status in ('approved','rejected','cancelled'))
      when 'refund_due' then (p_from_status in ('draft','open','partial') and p_to_status in ('partial','paid','cancelled'))
      when 'customer_receivable' then (p_from_status in ('draft','open','partial') and p_to_status in ('partial','paid','cancelled'))
      when 'purchase' then (
        (p_from_status in ('draft','open') and p_to_status in ('ordered','cancelled'))
        or (p_from_status='ordered' and p_to_status in ('partially_received','received','cancelled'))
        or (p_from_status='partially_received' and p_to_status='received')
        or (p_from_status='received' and p_to_status='invoice_review')
        or (p_from_status='invoice_review' and p_to_status='closed')
      )
      when 'supplier' then (p_from_status in ('open','draft') and p_to_status in ('approved','rejected','closed'))
      when 'tax_estimate' then (p_from_status in ('draft','open','pending_review') and p_to_status in ('approved','rejected','cancelled','closed'))
      when 'business_goal' then (p_from_status in ('draft','open','approved','in_progress') and p_to_status in ('approved','in_progress','closed','cancelled'))
      when 'subscription_request' then (p_from_status in ('open','draft','pending_review') and p_to_status in ('approved','rejected','cancelled','closed'))
      when 'support_chat' then (p_from_status in ('open','waiting_customer','in_progress') and p_to_status in ('waiting_customer','in_progress','closed','cancelled'))
      -- Activity-specific work-order states. Keep this allowlist aligned with
      -- apps/web/naxa-services/src/erp/activity-workflows.ts and Android.
      when 'work_order' then (
        (p_from_status in ('open','received') and p_to_status in ('diagnostic','quote_pending','measurement','proof_ready','planning','approved','in_progress','cancelled'))
        or (p_from_status='diagnostic' and p_to_status in ('quote_pending','awaiting_approval','waiting_parts','in_progress','cancelled'))
        or (p_from_status='measurement' and p_to_status in ('quote_pending','fitting','cancelled'))
        or (p_from_status='quote_pending' and p_to_status in ('waiting_customer','awaiting_approval','approved','proof_ready','cancelled'))
        or (p_from_status in ('waiting_customer','awaiting_approval') and p_to_status in ('approved','cancelled'))
        or (p_from_status='approved' and p_to_status in ('waiting_parts','fabrication','production','planning','in_progress'))
        or (p_from_status='waiting_parts' and p_to_status in ('fabrication','production','in_progress'))
        or (p_from_status='fabrication' and p_to_status='quality_check')
        or (p_from_status='fitting' and p_to_status in ('in_progress','quality_check','ready'))
        or (p_from_status='proof_ready' and p_to_status in ('approved','production','cancelled'))
        or (p_from_status='production' and p_to_status='quality_check')
        or (p_from_status='planning' and p_to_status in ('on_site','shooting','installation','cancelled'))
        or (p_from_status='on_site' and p_to_status in ('in_progress','quality_check'))
        or (p_from_status='shooting' and p_to_status='post_production')
        or (p_from_status='post_production' and p_to_status='quality_check')
        or (p_from_status='installation' and p_to_status in ('quality_check','ready'))
        or (p_from_status='in_progress' and p_to_status in ('fitting','quality_check','ready'))
        or (p_from_status='quality_check' and p_to_status in ('fabrication','production','post_production','installation','fitting','in_progress','ready'))
        or (p_from_status='ready' and p_to_status='delivered')
        or (p_from_status='delivered' and p_to_status='closed')
      )
      when 'repair_order' then (
        (p_from_status in ('open','received') and p_to_status in ('diagnostic','cancelled'))
        or (p_from_status='diagnostic' and p_to_status in ('quote_pending','awaiting_approval','in_progress','cancelled'))
        or (p_from_status='quote_pending' and p_to_status in ('waiting_customer','awaiting_approval','approved','cancelled'))
        or (p_from_status in ('waiting_customer','awaiting_approval') and p_to_status in ('approved','cancelled'))
        or (p_from_status='approved' and p_to_status in ('waiting_parts','in_progress'))
        or (p_from_status='waiting_parts' and p_to_status='in_progress')
        or (p_from_status='in_progress' and p_to_status='quality_check')
        or (p_from_status='quality_check' and p_to_status in ('in_progress','ready'))
        or (p_from_status='ready' and p_to_status='delivered')
        or (p_from_status='delivered' and p_to_status='closed')
      )
      when 'service_order' then (
        (p_from_status in ('open','received') and p_to_status in ('quote_pending','approved','planning','in_progress','cancelled'))
        or (p_from_status='diagnostic' and p_to_status in ('quote_pending','approved','cancelled'))
        or (p_from_status='quote_pending' and p_to_status in ('waiting_customer','approved','cancelled'))
        or (p_from_status='waiting_customer' and p_to_status in ('approved','cancelled'))
        or (p_from_status='approved' and p_to_status in ('planning','on_site','in_progress','cancelled'))
        or (p_from_status='planning' and p_to_status in ('on_site','cancelled'))
        or (p_from_status='on_site' and p_to_status='in_progress')
        or (p_from_status='in_progress' and p_to_status='quality_check')
        or (p_from_status='quality_check' and p_to_status in ('in_progress','ready'))
        or (p_from_status='ready' and p_to_status='delivered')
        or (p_from_status='delivered' and p_to_status='closed')
      )
      when 'appointment_waitlist' then (p_from_status in ('open','contacted') and p_to_status in ('contacted','booked','cancelled'))
      when 'staff_clock_in' then (p_from_status='open' and p_to_status in ('closed','cancelled'))
      when 'staff_clock_out' then (p_from_status='open' and p_to_status in ('closed','cancelled'))
      when 'staff_break_start' then (p_from_status='open' and p_to_status in ('closed','cancelled'))
      when 'staff_break_end' then (p_from_status='open' and p_to_status in ('closed','cancelled'))
      when 'staff_commission' then (p_from_status in ('pending_review','draft','approved') and p_to_status in ('approved','rejected','paid'))
      when 'staff_advance' then (p_from_status in ('pending_review','draft','approved') and p_to_status in ('approved','rejected','paid'))
      when 'staff_bonus' then (p_from_status in ('pending_review','draft','approved') and p_to_status in ('approved','rejected','paid'))
      else false
    end;
  end if;
  if v_activity is not null then v_allowed:=v_expected_type=p_record_type and public.ns_activity_workflow_transition_allowed(v_activity,p_from_status,p_to_status); end if;
  if not v_allowed then raise exception 'NAXA_MANAGEMENT_TRANSITION_FORBIDDEN'; end if;

  v_paid:=v_record.paid_xaf;
  v_metadata:=v_record.metadata_json || coalesce(p_metadata_json_delta,'{}'::jsonb);
  if p_record_type in ('invoice','refund_due','customer_receivable') then
    if p_to_status in ('partial','paid') then
      if coalesce(jsonb_typeof(p_metadata_json_delta->'paid_xaf'),'')<>'number'
        or coalesce(p_metadata_json_delta->>'paid_xaf','') !~ '^[0-9]{1,18}$' then
        raise exception 'NAXA_FINANCIAL_SETTLEMENT_REQUIRED';
      end if;
      v_paid:=(p_metadata_json_delta->>'paid_xaf')::bigint;
      if v_paid<=v_record.paid_xaf or v_paid>v_record.amount_xaf
         or (p_to_status='paid' and v_paid<>v_record.amount_xaf)
         or (p_to_status='partial' and v_paid>=v_record.amount_xaf)
      then raise exception 'NAXA_FINANCIAL_SETTLEMENT_INVALID'; end if;
    elsif p_to_status='cancelled' and v_record.paid_xaf<>0 then
      raise exception 'NAXA_FINANCIAL_CANCEL_REQUIRES_REVERSAL';
    end if;
    v_metadata:=v_metadata-'paid_xaf';
  end if;
  if p_to_status='received' and p_record_type='inventory_transfer' then
    return jsonb_build_object('record_id',p_record_id,'status','received',
      'revision',v_record.revision,'idempotent',true,'specialized_receipt_already_applied',true);
  end if;
  update public.ns_management_records
    set status=p_to_status,paid_xaf=v_paid,metadata_json=v_metadata,revision=revision+1,updated_at=now()
    where id=p_record_id and org_id=p_org_id and site_id=p_site_id
    returning * into v_record;
  insert into public.ns_management_record_events(
    id,org_id,site_id,record_id,from_status,to_status,reason,actor_member_id,revision,occurred_at
  ) values (
    gen_random_uuid(),p_org_id,p_site_id,p_record_id,p_from_status,p_to_status,
    trim(p_reason),v_member,v_record.revision,coalesce(p_transitioned_at,now())
  );
  return jsonb_build_object('record_id',p_record_id,'record_type',p_record_type,
    'status',v_record.status,'revision',v_record.revision,'paid_xaf',v_record.paid_xaf,'amount_xaf',v_record.amount_xaf,'updated',true);
end;
$naxa$;

create or replace function public.ns_record_charge_payment_at_due(
 p_org uuid,p_site uuid,p_charge uuid,p_amount bigint,p_key uuid,p_method text,p_reference text,p_due timestamptz
) returns jsonb language plpgsql security invoker set search_path='' as $naxa$
declare v_due timestamptz; v_active boolean; v_result jsonb;
begin
 if public.ns_current_member_id(p_org) is null or not public.ns_can_operate_site(p_org,p_site) then
   raise exception 'NAXA_CHARGE_PAYMENT_FORBIDDEN';
 end if;
 select next_due_at into v_due from public.ns_recurring_charges
 where id=p_charge and org_id=p_org and site_id=p_site for update;
 if not found or p_due is null or v_due is distinct from p_due then
   raise exception 'NAXA_CHARGE_DUE_CONFLICT';
 end if;
 v_result:=public.ns_record_charge_payment(p_org,p_site,p_charge,p_amount,p_key,p_method,p_reference);
 select next_due_at,active into v_due,v_active from public.ns_recurring_charges where id=p_charge;
 return v_result || jsonb_build_object('next_due_at',v_due,'active',v_active);
end;
$naxa$;
revoke all on function public.ns_record_charge_payment_at_due(uuid,uuid,uuid,bigint,uuid,text,text,timestamptz) from public,anon,authenticated;
grant execute on function public.ns_record_charge_payment_at_due(uuid,uuid,uuid,bigint,uuid,text,text,timestamptz) to service_role;
do $patch$
declare d text; old text:=$old$v_result := public.ns_record_charge_payment(
        p_org_id, p_site_id, (p_payload->>'charge_id')::uuid,
        (p_payload->>'amount_xaf')::bigint,
        coalesce((p_payload->>'payment_id')::uuid, p_event_id),
        coalesce(p_payload->>'payment_method','manual'),
        nullif(p_payload->>'payment_reference','')
      );$old$;
begin
 select pg_get_functiondef('public.ns_apply_sync_event(uuid,uuid,uuid,uuid,uuid,bigint,text,text,text,jsonb)'::regprocedure) into d;
 if (length(d)-length(replace(d,old,'')))/length(old)<>1 then raise exception 'NAXA_V23_SYNC_PATCH_DRIFT'; end if;
 d:=replace(d,old,$new$v_result := public.ns_record_charge_payment_at_due(
        p_org_id, p_site_id, (p_payload->>'charge_id')::uuid,
        (p_payload->>'amount_xaf')::bigint,
        coalesce((p_payload->>'payment_id')::uuid, p_event_id),
        coalesce(p_payload->>'payment_method','manual'),
        nullif(p_payload->>'payment_reference',''),
        nullif(p_payload->>'reference_due_at','')::timestamptz
      );$new$);
 execute d;
end;
$patch$;
rollback;
