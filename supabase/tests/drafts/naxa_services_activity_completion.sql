-- Exercise the same sync entry point used by enrolled clients for each generic activity.
RESET ROLE;
INSERT INTO public.ns_devices(id, account_id, installation_id, platform, label, remember_device, session_id)
VALUES ('80000000-0000-4000-8000-000000000099', '50000000-0000-4000-8000-000000000001',
  'ci-activity-web', 'web', 'Activity peer', true, 'ci-activity-web-session');
SET ROLE authenticated;
DO $activity_completion$
DECLARE
  org_id constant uuid := '20000000-0000-4000-8000-000000000001';
  site_id constant uuid := '30000000-0000-4000-8000-000000000001';
  device_id constant uuid := '80000000-0000-4000-8000-000000000001';
  peer_device constant uuid := '80000000-0000-4000-8000-000000000099';
  source_claims constant jsonb := current_setting('request.jwt.claims')::jsonb;
  peer_sequence bigint := 0;
  peer_cursor bigint := 0;
  page jsonb;
  event_device uuid;
  event_sequence bigint;
  scenario record;
  record_id uuid;
  scope jsonb;
  receipt jsonb;
  previous_status text;
  next_status text;
  version integer;
  sequence_number bigint := 172;
BEGIN
  FOR scenario IN
    SELECT * FROM (VALUES
      ('coiffure', 'service_order', '{"style":"tresses","technique":"Nattes longues"}'::jsonb,
       'approved in_progress quality_check ready delivered closed'),
      ('couture', 'work_order', '{"garment":"Robe","measurements":"Tour poitrine 92 cm"}'::jsonb,
       'measurement quote_pending approved in_progress quality_check ready delivered closed'),
      ('beaute', 'service_order', '{"treatment":"soin_visage","protocol":"Protocole esthétique non médical"}'::jsonb,
       'approved in_progress quality_check ready delivered closed'),
      ('parfumerie', 'work_order', '{"product":"Parfum","format":"50ml","family":"floral"}'::jsonb,
       'quote_pending approved in_progress quality_check ready delivered closed'),
      ('reparation', 'repair_order', '{"device":"Téléphone","fault":"Écran fissuré"}'::jsonb,
       'diagnostic awaiting_approval approved in_progress quality_check ready delivered closed'),
      ('menuiserie', 'work_order', '{"piece":"Table","dimensions":"120 x 80 x 75 cm"}'::jsonb,
       'diagnostic quote_pending approved fabrication quality_check ready delivered closed'),
      ('garage', 'repair_order', '{"vehicle":"Toyota Yaris","odometer":"120000","fault":"Freinage"}'::jsonb,
       'diagnostic quote_pending approved in_progress quality_check ready delivered closed'),
      ('nettoyage', 'service_order', '{"site":"Bureau client","tasks":"Nettoyage quotidien"}'::jsonb,
       'quote_pending approved planning on_site in_progress quality_check ready delivered closed'),
      ('domicile', 'service_order', '{"address":"Quartier Bonapriso","service":"Réparation plomberie"}'::jsonb,
       'approved planning on_site in_progress quality_check ready delivered closed'),
      ('impression', 'work_order', '{"format":"A4","quantity":"100"}'::jsonb,
       'quote_pending proof_ready production quality_check ready delivered closed'),
      ('photo_evenementiel', 'work_order', '{"event":"Cérémonie","date":"2026-11-24","deliverables":"Album et galerie numérique"}'::jsonb,
       'planning shooting post_production quality_check ready delivered closed'),
      ('autre', 'work_order', '{"service":"Prestation personnalisée","specifications":"Périmètre défini avec le client"}'::jsonb,
       'quote_pending approved in_progress quality_check ready delivered closed')
    ) AS cases(profile, kind, fields, lifecycle)
  LOOP
    record_id := gen_random_uuid();
    scope := jsonb_build_object('record_id', record_id, 'org_id', org_id, 'site_id', site_id);
    previous_status := 'received';
    version := 1;
    sequence_number := sequence_number + 1;
    receipt := public.ns_apply_sync_event(org_id, site_id, null, device_id, gen_random_uuid(),
      sequence_number, scenario.kind, record_id::text, scenario.kind || '.created',
      scope || jsonb_build_object('record_type', scenario.kind, 'reference', 'CI-' || scenario.profile,
        'title', 'Recette ' || scenario.profile, 'amount_xaf', 0, 'paid_xaf', 0, 'status', previous_status,
        'metadata_json', jsonb_build_object('activity_profile', scenario.profile, 'workflow_version', 2,
          'fields', scenario.fields)));
    IF receipt->>'status' IS DISTINCT FROM 'applied'
       OR receipt->'result'->>'status' IS DISTINCT FROM previous_status THEN
      RAISE EXCEPTION 'Creation failed for %: %', scenario.profile, receipt;
    END IF;

    FOREACH next_status IN ARRAY string_to_array(scenario.lifecycle, ' ') LOOP
      IF next_status = 'closed' THEN
        PERFORM set_config('request.jwt.claims',
          (source_claims || jsonb_build_object('session_id','ci-activity-web-session'))::text, true);
        LOOP
          page := public.ns_pull_sync_changes(org_id, peer_device, peer_cursor, 50);
          peer_cursor := (page->>'next_cursor')::bigint;
          EXIT WHEN EXISTS (SELECT FROM jsonb_array_elements(page->'changes') e
              WHERE e->>'aggregate_id' = record_id::text AND e->>'source_device_id' = device_id::text
                AND e#>>'{payload,server_result,status}' = previous_status
                AND (e#>>'{payload,server_result,revision}')::integer = version);
          IF NOT (page->>'has_more')::boolean THEN
            RAISE EXCEPTION 'Web peer missing % at revision %', scenario.profile, version;
          END IF;
        END LOOP;
        peer_sequence := peer_sequence + 1;
        event_device := peer_device;
        event_sequence := peer_sequence;
      ELSE
        sequence_number := sequence_number + 1;
        event_device := device_id;
        event_sequence := sequence_number;
      END IF;
      receipt := public.ns_apply_sync_event(org_id, site_id, null, event_device, gen_random_uuid(),
        event_sequence, scenario.kind, record_id::text, scenario.kind || '.status_changed',
        scope || jsonb_build_object('from_status', previous_status, 'to_status', next_status,
          'reason', 'Recette du parcours complet', 'expected_version', version, 'metadata_json_delta', '{}'::jsonb));
      version := version + 1;
      IF receipt->>'status' IS DISTINCT FROM 'applied'
         OR receipt->'result'->>'status' IS DISTINCT FROM next_status
         OR (receipt->'result'->>'revision')::integer IS DISTINCT FROM version THEN
        RAISE EXCEPTION 'Transition failed for % at %: %', scenario.profile, next_status, receipt;
      END IF;
      previous_status := next_status;
    END LOOP;

    PERFORM set_config('request.jwt.claims', source_claims::text, true);
    page := public.ns_pull_sync_changes(org_id, device_id, peer_cursor, 50);
    IF NOT EXISTS (SELECT FROM jsonb_array_elements(page->'changes') e
        WHERE e->>'aggregate_id' = record_id::text AND e->>'source_device_id' = peer_device::text
          AND e#>>'{payload,server_result,status}' = 'closed'
          AND (e#>>'{payload,server_result,revision}')::integer = version) THEN
      RAISE EXCEPTION 'Android peer missing final revision for %', scenario.profile;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.ns_management_records r
        WHERE r.id = record_id AND r.record_type = scenario.kind AND r.status = 'closed'
          AND r.revision = version AND r.metadata_json->>'activity_profile' = scenario.profile) THEN
      RAISE EXCEPTION 'Missing closed record for %', scenario.profile;
    END IF;
  END LOOP;
END
$activity_completion$;
