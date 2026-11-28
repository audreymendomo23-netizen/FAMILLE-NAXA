#!/usr/bin/env bash
set -euo pipefail
[[ "${GITHUB_ACTIONS:-}" == true && "${GITHUB_REPOSITORY:-}" == audreymendomo23-netizen/FAMILLE-NAXA && "${GITHUB_REF:-}" == refs/heads/work/grillad-foundation-20261127 ]] || exit 1
unset SUPABASE_ACCESS_TOKEN SUPABASE_DB_PASSWORD
export GRILLAD_CI_LOCAL=1
work="$RUNNER_TEMP/grillad-local-stack"
mkdir -p "$work"
cd "$work"
supabase init
# Fresh CLI project, never linked to a hosted project.
python3 - <<'PY'
from pathlib import Path
import re
p=Path('supabase/config.toml')
s=p.read_text()
# Test-only provider configuration enables GoTrue phone password login.
# No real provider account, no SMS is sent; local test numbers only.
s=re.sub(r'(?ms)^\[auth\.sms\.twilio\]\s*\n.*?(?=^\[|\Z)', '',s)
s += '\n[auth.sms.twilio]\nenabled = true\naccount_sid = "placeholder"\nmessage_service_sid = "placeholder"\nauth_token = "placeholder"\n'
s=re.sub(r'(?ms)(^\[auth.sms\]\s*\n)(.*?)(?=^\[|\Z)', lambda m:m[1]+re.sub(r'(?m)^enable_signup\s*=.*$', 'enable_signup = true',m[2]),s)
p.write_text(s)
PY
supabase start --help >/dev/null
supabase start -x studio,imgproxy,edge-runtime,logflare,vector,supavisor,realtime,storage-api,postgres-meta,mailpit
supabase status -o env > "$RUNNER_TEMP/grillad-local.env"
chmod 600 "$RUNNER_TEMP/grillad-local.env"
source "$RUNNER_TEMP/grillad-local.env"
[[ "$API_URL" == http://127.0.0.1:54321 || "$API_URL" == http://localhost:54321 ]] || exit 1
[[ "$DB_URL" == postgresql://postgres:postgres@127.0.0.1:54322/postgres || "$DB_URL" == postgresql://postgres:postgres@localhost:54322/postgres ]] || exit 1
export PGHOST=127.0.0.1 PGPORT=54322 PGUSER=postgres PGPASSWORD=postgres PGDATABASE=postgres
export GRILLAD_LOCAL_API="$API_URL" GRILLAD_LOCAL_ANON="$ANON_KEY" GRILLAD_LOCAL_SERVICE="$SERVICE_ROLE_KEY"
cd "$GITHUB_WORKSPACE"
# GoTrue's actual auth schema is retained; never load the mock auth bootstrap.
docker exec supabase_db_grillad-local-stack psql -X -U supabase_admin -d postgres -v ON_ERROR_STOP=1 -c 'alter table auth.sessions add column if not exists tag text; grant select, update on auth.sessions to postgres; grant select on auth.users to postgres;'
psql -X -v ON_ERROR_STOP=1 -c 'create extension if not exists pgcrypto;'
psql -X -v ON_ERROR_STOP=1 -f supabase/drafts/0001_famille_core_proposed.sql
psql -X -v ON_ERROR_STOP=1 -f supabase/migrations/0002_famille_core_rls.sql
psql -X -v ON_ERROR_STOP=1 -f supabase/drafts/0003_prompt_0_3_contextual_rls.sql
psql -X -v ON_ERROR_STOP=1 -f supabase/drafts/grillad_business_v1.sql
psql -X -v ON_ERROR_STOP=1 -f supabase/drafts/grillad_attendance_v1.sql
psql -X -v ON_ERROR_STOP=1 -f supabase/drafts/0004_prompt_0_4_account_lifecycle.sql
psql -X -v ON_ERROR_STOP=1 -f supabase/drafts/grillad_auth_bridge_v1.sql
psql -X -v ON_ERROR_STOP=1 -f supabase/drafts/grillad_daily_v1.sql
psql -X -v ON_ERROR_STOP=1 -f supabase/drafts/grillad_connect_v1.sql
psql -X -v ON_ERROR_STOP=1 -f supabase/drafts/grillad_pilotage_v1.sql
psql -X -v ON_ERROR_STOP=1 -f supabase/drafts/grillad_security_v1.sql
psql -X -v ON_ERROR_STOP=1 -f supabase/drafts/grillad_push_v1.sql
psql -X -v ON_ERROR_STOP=1 -f supabase/drafts/grillad_prediction_v1.sql
psql -X -v ON_ERROR_STOP=1 -f supabase/drafts/grillad_profile_v1.sql
psql -X -v ON_ERROR_STOP=1 -f supabase/drafts/grillad_operations_v1.sql
psql -X -v ON_ERROR_STOP=1 -f supabase/drafts/grillad_lifecycle_followup_v1.sql
psql -X -v ON_ERROR_STOP=1 -f supabase/drafts/grillad_lifecycle_guards_v1.sql
psql -X -v ON_ERROR_STOP=1 -f supabase/drafts/grillad_manual_tenders_v1.sql
psql -X -v ON_ERROR_STOP=1 -f supabase/drafts/grillad_subscription_proofs_v1.sql
psql -X -v ON_ERROR_STOP=1 -f supabase/drafts/grillad_connect_tenders_v1.sql
psql -X -v ON_ERROR_STOP=1 -f supabase/drafts/grillad_subscription_claims_v1.sql
psql -X -v ON_ERROR_STOP=1 -f supabase/drafts/grillad_identity_review_v1.sql
psql -X -v ON_ERROR_STOP=1 -f supabase/drafts/grillad_capture_devices_v1.sql
psql -X -v ON_ERROR_STOP=1 -f supabase/drafts/grillad_connect_pairs_v1.sql
psql -X -v ON_ERROR_STOP=1 -f supabase/drafts/grillad_capture_match_v1.sql
psql -X -v ON_ERROR_STOP=1 -f supabase/drafts/grillad_push_transport_v1.sql
psql -X -v ON_ERROR_STOP=1 -f supabase/drafts/grillad_transverse_v1.sql
node scripts/grillad/local-real-auth.mjs provision
psql -X -v ON_ERROR_STOP=1 -f supabase/local-tests/grillad_real_auth_seed.sql
printf '%s\n' 'NOTIFY pgrst, '\''reload schema'\'';' | psql -X -v ON_ERROR_STOP=1
# Local-only keys remain in private runner files; never artifacts or hosted credentials.
printf 'GRILLAD_CI_LOCAL=1\nGRILLAD_LOCAL_API=%s\nGRILLAD_LOCAL_ANON=%s\nGRILLAD_LOCAL_SERVICE=%s\n' "$GRILLAD_LOCAL_API" "$GRILLAD_LOCAL_ANON" "$GRILLAD_LOCAL_SERVICE" >> "$GITHUB_ENV"
