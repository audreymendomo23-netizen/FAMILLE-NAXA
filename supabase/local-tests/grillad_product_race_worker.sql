\set ON_ERROR_STOP on
select set_config('grillad.test.app',(select id::text from famille_core.applications where code='grillad'),false);
set role authenticated;
select set_config('request.jwt.claim.sub',:'actor',false);
select set_config('request.jwt.claims',jsonb_build_object('session_id',:'session','app_metadata',jsonb_build_object('active_app_id',current_setting('grillad.test.app')))::text,false);
select set_config('grillad.test.event',:'event',false);
select set_config('grillad.test.qty',:'qty',false);
-- Each invocation has its own DB connection and transaction; a rejected stock race is expected only for qty=2.
do $test$ declare o uuid:='92000000-0000-0000-0000-000000000001';a uuid:='93000000-0000-0000-0000-000000000001';b uuid:='93000000-0000-0000-0000-000000000002';i uuid:='94000000-0000-0000-0000-000000000099';e uuid:=current_setting('grillad.test.event')::uuid;q int:=current_setting('grillad.test.qty')::int;p jsonb;v jsonb;d date:=(now() at time zone 'Africa/Douala')::date;
begin
 begin perform public.grillad_snapshot(o,b,d,d);raise exception 'REC-25 seller saw B';exception when insufficient_privilege then null;end;
 p:=jsonb_build_object('item',i,'qty',q,'price',1000,'received',q*1000);
 begin
  v:=public.grillad_action(o,a,e,'sell',p);
  if (v->>'total')::int<>q*1000 then raise exception 'wrong total';end if;
  if public.grillad_action(o,a,e,'sell',p)<>v then raise exception 'REC-14 replay';end if;
 exception when invalid_parameter_value then
  if q<>2 or SQLERRM<>'GRILLAD_STOCK' then raise;end if;
 end;
end $test$;
