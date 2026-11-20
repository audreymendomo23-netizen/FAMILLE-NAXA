-- NAXA SERVICES v2 additive draft. NOT applied to any Supabase project.
-- Test only on an isolated environment after review of the canonical schema/grants.
begin;
alter table public.ns_organizations
  add column if not exists activity_profile text,
  add column if not exists activity_profile_selected_at timestamptz,
  add column if not exists activity_profile_selected_by uuid;

alter table public.ns_organizations drop constraint if exists ns_organizations_activity_profile_check;
alter table public.ns_organizations add constraint ns_organizations_activity_profile_check
  check (activity_profile is null or activity_profile in (
    'pressing','coiffure','couture','beaute','parfumerie','reparation',
    'menuiserie','garage','nettoyage','domicile','impression','photo_evenementiel','autre'
  ));

alter table public.ns_organizations drop constraint if exists ns_organizations_activity_selection_metadata_check;
alter table public.ns_organizations add constraint ns_organizations_activity_selection_metadata_check
  check (
    (activity_profile is null and activity_profile_selected_at is null and activity_profile_selected_by is null)
    or (activity_profile is not null and activity_profile_selected_at is not null and activity_profile_selected_by is not null)
  );

alter table public.ns_organizations drop constraint if exists ns_organizations_activity_profile_selected_by_fkey;
alter table public.ns_organizations add constraint ns_organizations_activity_profile_selected_by_fkey
  foreign key (activity_profile_selected_by) references public.ns_members(id) on delete restrict;

alter table public.ns_members
  add column if not exists preferred_locale text,
  add column if not exists discovery_completed_at timestamptz,
  add column if not exists tour_completed_at timestamptz;
alter table public.ns_members
  drop constraint if exists ns_members_preferred_locale_check;
alter table public.ns_members
  add constraint ns_members_preferred_locale_check
  check (preferred_locale is null or preferred_locale in ('fr','en','ff-CM'));

create table if not exists public.ns_legal_acceptances (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.ns_organizations(id) on delete restrict,
  member_id uuid not null references public.ns_members(id) on delete restrict,
  document_type text not null check (document_type in ('terms','privacy')),
  document_version text not null,
  locale text not null check (locale in ('fr','en')),
  accepted_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (member_id, document_type, document_version)
);
create index if not exists ns_legal_acceptances_org_member_idx
  on public.ns_legal_acceptances(org_id, member_id, accepted_at desc);

alter table public.ns_legal_acceptances enable row level security;
revoke all on public.ns_legal_acceptances from anon, authenticated;
grant all on public.ns_legal_acceptances to service_role;

-- A non-null activity profile cannot be changed. The trigger protects against concurrent first-choice requests.
create or replace function public.ns_enforce_activity_profile_once()
returns trigger language plpgsql set search_path = ''
as $naxa$
begin
  if old.activity_profile is not null and new.activity_profile is distinct from old.activity_profile then
    raise exception 'NAXA_ACTIVITY_PROFILE_LOCKED';
  end if;
  if old.activity_profile is not null and (
    new.activity_profile_selected_at is distinct from old.activity_profile_selected_at
    or new.activity_profile_selected_by is distinct from old.activity_profile_selected_by
  ) then
    raise exception 'NAXA_ACTIVITY_PROFILE_AUDIT_LOCKED';
  end if;
  if old.activity_profile is null and new.activity_profile is not null
     and (new.activity_profile_selected_at is null or new.activity_profile_selected_by is null) then
    raise exception 'NAXA_ACTIVITY_PROFILE_SELECTION_METADATA_REQUIRED';
  end if;
  return new;
end;
$naxa$;
drop trigger if exists ns_organizations_activity_profile_once on public.ns_organizations;
create trigger ns_organizations_activity_profile_once
before update on public.ns_organizations
for each row execute function public.ns_enforce_activity_profile_once();
revoke all on function public.ns_enforce_activity_profile_once() from public, anon, authenticated;
commit;
