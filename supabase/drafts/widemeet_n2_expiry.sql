-- Service-only idempotent deadline closure; no client can supply a clock.
begin;
create function public.wm_close_due_rooms(p_limit integer default 100)
returns table(room_id uuid) language plpgsql security invoker set search_path=pg_catalog,public as $wm$
declare item public.wm_rooms%rowtype;cutoff bigint:=floor(extract(epoch from clock_timestamp())*1000)::bigint;
begin
 if p_limit is null or p_limit not between 1 and 100 then return;end if;
 for item in select r.* from public.wm_rooms r where r.state->>'status' in ('open','paused') and (r.state->>'endMs')::bigint<=cutoff order by (r.state->>'endMs')::bigint,r.id limit p_limit for update skip locked loop
  update public.wm_rooms set revision=item.revision+1,state=item.state||jsonb_build_object('revision',item.revision+1,'status','ended','recording','off','closedMs',(item.state->>'endMs')::bigint,'closeReason','deadline') where id=item.id and revision=item.revision;
  if found then room_id:=item.id;return next;end if;
 end loop;
end $wm$;
revoke all on function public.wm_close_due_rooms(integer) from public,anon,authenticated;
grant execute on function public.wm_close_due_rooms(integer) to service_role;
commit;
