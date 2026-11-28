\set ON_ERROR_STOP on
begin;
insert into auth.users(id) values('10000000-0000-4000-8000-000000000001'),('10000000-0000-4000-8000-000000000002'),('10000000-0000-4000-8000-000000000003'),('10000000-0000-4000-8000-000000000004');
insert into auth.sessions(id,user_id) select ('20000000-0000-4000-8000-00000000000'||n)::uuid,('10000000-0000-4000-8000-00000000000'||n)::uuid from generate_series(1,4)n;
insert into naxa_control_private.operators(user_id,role_code) values('10000000-0000-4000-8000-000000000001','administrator'),('10000000-0000-4000-8000-000000000002','finance'),('10000000-0000-4000-8000-000000000003','support');
set local role authenticated;
do $$declare n int; d jsonb; begin
 for n in 1..4 loop
 perform set_config('request.jwt.claim.sub','10000000-0000-4000-8000-00000000000'||n,true);
 perform set_config('request.jwt.claims',jsonb_build_object('aal','aal2','session_id','20000000-0000-4000-8000-00000000000'||n)::text,true);
 if n=4 then begin perform public.naxa_control_dashboard(null);raise exception 'ordinary user allowed';exception when insufficient_privilege then null;end;
 else
 d:=public.naxa_control_dashboard(null);
 if n=1 and (not d?'accounts' or d?'payments' or d?'tickets') then raise exception 'admin isolation';end if;
 if n=2 and (not d?'payments' or d?'accounts' or d?'tickets') then raise exception 'finance isolation';end if;
 if n=3 and (not d?'tickets' or d?'payments' or d?'accounts') then raise exception 'support isolation';end if;
 if n<>3 then begin perform public.naxa_control_ticket_transition(gen_random_uuid(),'open','in_progress','test reason');raise exception 'cross-role write';exception when insufficient_privilege then null;end;end if;
 end if;
 end loop;
 perform set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
 perform set_config('request.jwt.claims','{"aal":"aal1","session_id":"20000000-0000-4000-8000-000000000001"}',true);
 begin perform public.naxa_control_dashboard(null);raise exception 'aal1 allowed';exception when insufficient_privilege then null;end;
end $$;
rollback;
