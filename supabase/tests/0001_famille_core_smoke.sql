-- Grouped smoke tests for the isolated PostgreSQL 17 draft.
-- This file runs only against the ephemeral CI database, never Supabase Replay/Production.
\set ON_ERROR_STOP on

DO $$
DECLARE
  app_a uuid;
  app_b uuid;
  org_a uuid;
  org_b uuid;
  loc_a uuid;
  loc_b uuid;
  user_a uuid := '00000000-0000-0000-0000-000000000001';
  member_a uuid;
  role_a text := 'manager';
  plan_a uuid;
  plan_b uuid;
  table_count integer;
  policy_count integer;
  grants_count integer;
BEGIN
  SELECT count(*) INTO table_count
  FROM information_schema.tables
  WHERE table_schema='famille_core' AND table_type='BASE TABLE';
  IF table_count <> 22 THEN
    RAISE EXCEPTION 'Expected 22 core tables, got %', table_count;
  END IF;

  IF (SELECT count(*) FROM famille_core.applications) <> 10 THEN
    RAISE EXCEPTION 'Expected exactly 10 seeded applications';
  END IF;

  INSERT INTO auth.users(id,email) VALUES (user_a,'smoke@example.invalid');
  INSERT INTO famille_core.identities(user_id,display_name) VALUES(user_a,'Smoke User');

  SELECT id INTO app_a FROM famille_core.applications WHERE code='kiosko';
  SELECT id INTO app_b FROM famille_core.applications WHERE code='bootik';

  INSERT INTO famille_core.organizations(legal_name,organization_type,created_by)
  VALUES ('Org A','merchant',user_a) RETURNING id INTO org_a;
  INSERT INTO famille_core.organizations(legal_name,organization_type,created_by)
  VALUES ('Org B','merchant',user_a) RETURNING id INTO org_b;

  INSERT INTO famille_core.organization_apps(organization_id,app_id,status)
  VALUES (org_a,app_a,'active'),(org_b,app_b,'active');

  INSERT INTO famille_core.locations(organization_id,code,name)
  VALUES (org_a,'A','Location A') RETURNING id INTO loc_a;
  INSERT INTO famille_core.locations(organization_id,code,name)
  VALUES (org_b,'B','Location B') RETURNING id INTO loc_b;

  INSERT INTO famille_core.memberships(user_id,organization_id,app_id,status,joined_at)
  VALUES(user_a,org_a,app_a,'active',now()) RETURNING id INTO member_a;

  INSERT INTO famille_core.role_catalog(app_id,role_code,display_name,scope_type)
  VALUES(app_a,role_a,'Manager','organization');
  INSERT INTO famille_core.role_catalog(app_id,role_code,display_name,scope_type)
  VALUES(app_b,'seller','Seller','location');

  -- Positive path: matching membership, app, organization and location.
  INSERT INTO famille_core.role_assignments(membership_id,app_id,organization_id,role_code,location_id)
  VALUES(member_a,app_a,org_a,role_a,loc_a);

  -- Negative path 1: role assignment must not cross application scope.
  BEGIN
    INSERT INTO famille_core.role_assignments(membership_id,app_id,organization_id,role_code)
    VALUES(member_a,app_b,org_a,'seller');
    RAISE EXCEPTION 'Cross-app role assignment unexpectedly succeeded';
  EXCEPTION WHEN foreign_key_violation THEN
    NULL;
  END;

  -- Negative path 2: role assignment must not cross organization/location scope.
  BEGIN
    INSERT INTO famille_core.role_assignments(membership_id,app_id,organization_id,role_code,location_id)
    VALUES(member_a,app_a,org_a,role_a,loc_b);
    RAISE EXCEPTION 'Cross-organization location assignment unexpectedly succeeded';
  EXCEPTION WHEN foreign_key_violation THEN
    NULL;
  END;

  INSERT INTO famille_core.plans(app_id,code,name,amount_fcfa,billing_period)
  VALUES(app_a,'basic','Basic',1000,'monthly') RETURNING id INTO plan_a;
  INSERT INTO famille_core.plans(app_id,code,name,amount_fcfa,billing_period)
  VALUES(app_b,'basic','Basic',1000,'monthly') RETURNING id INTO plan_b;

  -- Positive path: subscription plan belongs to the enabled app.
  INSERT INTO famille_core.subscriptions(organization_id,app_id,plan_id)
  VALUES(org_a,app_a,plan_a);

  -- Negative path 3: a subscription cannot use a plan from another app.
  BEGIN
    INSERT INTO famille_core.subscriptions(organization_id,app_id,plan_id)
    VALUES(org_a,app_a,plan_b);
    RAISE EXCEPTION 'Cross-app subscription plan unexpectedly succeeded';
  EXCEPTION WHEN foreign_key_violation THEN
    NULL;
  END;

  SELECT count(*) INTO policy_count
  FROM pg_policies WHERE schemaname='famille_core';
  IF policy_count <> 0 THEN
    RAISE EXCEPTION 'Draft expected to have no policies before approval; found %', policy_count;
  END IF;

  SELECT count(*) INTO grants_count
  FROM information_schema.role_table_grants
  WHERE table_schema='famille_core' AND grantee IN ('anon','authenticated');
  IF grants_count <> 0 THEN
    RAISE EXCEPTION 'Draft unexpectedly grants Data API roles access before policy review';
  END IF;

  RAISE NOTICE 'PASS: 22 tables, 10 apps, positive constraints, 3 cross-scope denials, RLS enabled/no policies/no grants (default deny only).';
END $$;
