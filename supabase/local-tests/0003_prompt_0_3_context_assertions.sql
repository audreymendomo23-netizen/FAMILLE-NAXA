-- Run after candidate 0003 in the PostgreSQL 17 ephemeral test database.
-- This file asserts fail-closed behavior; fixture-specific cross-app tests must
-- set signed-claim simulation and real UUID fixtures in the harness.
do $$
declare v uuid;
begin
  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated","app_metadata":{}}', true);
  select famille_core.current_app_id() into v;
  if v is not null then raise exception 'FAIL: missing app claim must fail closed'; end if;

  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated","app_metadata":{"active_app_id":"not-a-uuid"}}', true);
  select famille_core.current_app_id() into v;
  if v is not null then raise exception 'FAIL: malformed app claim must fail closed'; end if;

  perform set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated","app_metadata":{"active_app_id":"00000000-0000-0000-0000-000000000010"}}', true);
  select famille_core.current_app_id() into v;
  if v is distinct from '00000000-0000-0000-0000-000000000010'::uuid then
    raise exception 'FAIL: valid trusted app claim not parsed';
  end if;
end $$;
