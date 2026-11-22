import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const sourcePath = join(root, "apps/android/naxa-services/src/main/java/cm/naxa/naxaservices/data/LocalErpStore.kt");
const coordinatorPath = join(root, "apps/android/naxa-services/src/main/java/cm/naxa/naxaservices/SupplierSyncCoordinator.kt");
const edgeContractPath = join(root, "supabase/functions/naxa-services-accounting/sync_contract.ts");
const erpUiPath = join(root, "apps/android/naxa-services/src/main/java/cm/naxa/naxaservices/ErpModules.kt");
const authApiPath = join(root, "apps/android/naxa-services/src/main/java/cm/naxa/naxaservices/auth/AuthApi.kt");
const manifestPath = join(root, "docs/naxa-services/NAXA_SERVICES_OUTBOX_REGISTRY_2026-11-22.json");

const source = readFileSync(sourcePath, "utf8");
const coordinator = readFileSync(coordinatorPath, "utf8");
const edgeContract = readFileSync(edgeContractPath, "utf8");
const erpUi = readFileSync(erpUiPath, "utf8");
const authApi = readFileSync(authApiPath, "utf8");
const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));

function splitArguments(input) {
  const result = [];
  let current = "";
  let depth = 0;
  let quote = null;
  let escaped = false;
  for (const ch of input) {
    if (quote) {
      current += ch;
      if (escaped) escaped = false;
      else if (ch === "\\") escaped = true;
      else if (ch === quote) quote = null;
      continue;
    }
    if (ch === '"' || ch === "'") { quote = ch; current += ch; continue; }
    if ("([{".includes(ch)) { depth++; current += ch; continue; }
    if (")]}".includes(ch)) { depth--; current += ch; continue; }
    if (ch === "," && depth === 0) { result.push(current.trim()); current = ""; continue; }
    current += ch;
  }
  if (current.trim()) result.push(current.trim());
  return result;
}
function normalize(value) { return value.replace(/\s+/g, " ").trim(); }
function normalizeAggregateType(value) {
  const normalized = normalize(value);
  if (normalized.startsWith('"') && normalized.endsWith('"')) return JSON.parse(normalized);
  if (normalized.startsWith("'") && normalized.endsWith("'")) return normalized.slice(1, -1);
  return normalized;
}

const sourceLines = source.split(/\r?\n/);
const discovered = [];
let method = "";
for (let i = 0; i < sourceLines.length; i++) {
  const signature = sourceLines[i].match(/^    (?:private )?(?:suspend )?fun ([A-Za-z0-9_]+)\s*\(/);
  if (signature) method = signature[1];
  if (!sourceLines[i].includes("enqueue(") || /fun enqueue\(/.test(sourceLines[i])) continue;
  const line = sourceLines[i];
  const start = line.indexOf("enqueue(") + "enqueue(".length;
  let depth = 1, quote = null, escaped = false, end = start;
  for (; end < line.length && depth > 0; end++) {
    const ch = line[end];
    if (quote) {
      if (escaped) escaped = false;
      else if (ch === "\\") escaped = true;
      else if (ch === quote) quote = null;
      continue;
    }
    if (ch === '"' || ch === "'") { quote = ch; continue; }
    if (ch === "(") depth++;
    else if (ch === ")") depth--;
  }
  assert.equal(depth, 0, "Unclosed enqueue call at line " + (i + 1));
  const args = splitArguments(line.slice(start, end - 1));
  assert.ok(args.length >= 5, "enqueue must have five args at line " + (i + 1));
  discovered.push({
    line: i + 1,
    method,
    aggregateType: normalizeAggregateType(args[1]),
    actionExpression: normalize(args[3]),
  });
}

assert.equal(discovered.length, manifest.source_callsite_count, "The actual number of outbox call sites changed.");
assert.equal(manifest.rows.length, manifest.source_callsite_count, "The registry must contain exactly one row per call site.");
const key = x => [x.method, x.aggregateType, normalize(x.actionExpression)].join("::");
const manifestMap = new Map();
for (const row of manifest.rows) {
  const rowKey = key({method:row.source.method,aggregateType:row.source.aggregateType,actionExpression:row.source.actionExpression});
  assert.ok(!manifestMap.has(rowKey), "Duplicate registry entry: " + row.id);
  manifestMap.set(rowKey, row);
  assert.ok(row.source.line > 0);
  assert.ok(row.action_codes.length > 0, "No concrete action code for " + row.id);
  assert.ok(row.classification && row.disposition, "Unclassified outbox call " + row.id);
  assert.ok(row.contract.source_of_truth, "No source of truth for " + row.id);
  assert.ok(row.contract.payload_fields.length > 0, "No contract fields for " + row.id);
  assert.ok(row.contract.scope && row.contract.actor && row.contract.device, "Missing scope/actor/device contract for " + row.id);
  assert.ok(row.contract.idempotency && row.contract.receipt && row.contract.conflict && row.contract.retry, "Incomplete consistency contract for " + row.id);
  assert.ok(row.contract.tests.length > 0, "No test criteria for " + row.id);
  if (row.classification === "REMOTE_MUTATION") {
    assert.equal(row.disposition, "SEND_AS_CANONICAL_MUTATION", "Remote mutation must be sent: " + row.id);
    assert.ok(row.contract.handler && !row.contract.handler.startsWith("No "), "Missing handler for " + row.id);
  } else {
    assert.notEqual(row.disposition, "SEND_AS_CANONICAL_MUTATION", "Non-mutation must not be sent: " + row.id);
    assert.ok(row.contract.reason || row.canonical_parent_action || row.contract.handler, "Missing exclusion/parent rationale: " + row.id);
  }
}
for (const call of discovered) {
  assert.ok(manifestMap.has(key(call)), "Outbox call missing from registry: line " + call.line + " " + key(call));
}
for (const row of manifest.rows) {
  const rowKey = key({method:row.source.method,aggregateType:row.source.aggregateType,actionExpression:row.source.actionExpression});
  const sourceCall = discovered.find(call => key(call) === rowKey);
  assert.ok(sourceCall, "Stale registry row: " + row.id + " " + rowKey);
  assert.equal(sourceCall.line, row.source.line, "Source line changed; refresh registry row " + row.id);
}

const supportedBlock = coordinator.match(/private val supportedActions = setOf\(([\s\S]*?)\n    \)/);
assert.ok(supportedBlock, "Cannot read SupplierSyncCoordinator supportedActions.");
const actualSupported = [...supportedBlock[1].matchAll(/"([^"]+)"/g)].map(m => m[1]).sort();
const registeredSupported = manifest.rows
  .filter(row => row.implementation_status === "CURRENTLY_SUPPORTED_BY_BOUNDED_COORDINATOR")
  .flatMap(row => row.action_codes).sort();
assert.deepEqual(actualSupported, registeredSupported, "Registry coordinator coverage differs from code.");
assert.deepEqual(
  actualSupported,
  [...(manifest.current_coordinator_supported_action_codes ?? [])].sort(),
  "Registry coordinator summary differs from code."
);
assert.ok(actualSupported.length > 0 && actualSupported.length <= 92, "Coordinator action coverage is outside the registry contract.");

const edgeActionsBlock = edgeContract.match(/const ATOMIC_SYNC_ACTIONS:[\\s\\S]*?=\\s*\\{([\\s\\S]*?)\\n\\};/);
assert.ok(edgeActionsBlock, "Cannot read the Edge atomic sync action allowlist.");
const edgeSupported = [...edgeActionsBlock[1].matchAll(/^\\s*"([^"]+)":\\s*\\{/gm)]
  .map(match => match[1]).sort();
assert.deepEqual(
  actualSupported,
  edgeSupported,
  "Android sync action coverage differs from the Edge allowlist."
);

function findKotlinFiles(dir) {
  const out = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) out.push(...findKotlinFiles(path));
    else if (entry.isFile() && entry.name.endsWith(".kt")) out.push(path);
  }
  return out;
}
const kotlinRoot = join(root, "apps/android/naxa-services/src");
const allKotlin = findKotlinFiles(kotlinRoot).map(path => readFileSync(path, "utf8")).join("\n");
for (const [legacyMethod, apiMethod] of [["createLocalSite","createSite"],["createLocalWorkstation","createWorkstation"]]) {
  const definitionPattern = new RegExp("\\bfun\\s+" + legacyMethod + "\\s*\\(", "g");
  const definitions = [...allKotlin.matchAll(definitionPattern)].length;
  const callPattern = new RegExp("\\b" + legacyMethod + "\\s*\\(", "g");
  const calls = [...allKotlin.matchAll(callPattern)].length;
  assert.equal(definitions, 1, "Expected one legacy helper definition: " + legacyMethod);
  assert.equal(calls, 1, "Legacy local helper must have no callers: " + legacyMethod);
  assert.match(authApi, new RegExp("suspend fun " + apiMethod + "\\s*\\("), "Direct API missing: " + apiMethod);
}
assert.match(erpUi, /api\.createSite\(/, "Live site-create UI must use the server API.");
assert.match(erpUi, /api\.createWorkstation\(/, "Live workstation-create UI must use the server API.");
assert.match(erpUi, /api\.updateOrganizationProfile\(/, "Organization profile must use the server API first.");

const counts = manifest.rows.reduce((out,row) => (out[row.classification]=(out[row.classification]||0)+1,out), {});
assert.deepEqual(counts, manifest.classification_counts, "Manifest classification totals are inconsistent.");
console.log(JSON.stringify({
  status:"PASS",
  source_call_sites:discovered.length,
  registry_rows:manifest.rows.length,
  classifications:counts,
  current_bounded_coordinator_actions:actualSupported.length,
  edge_allowed_sync_actions:edgeSupported.length,
  android_edge_action_parity:true,
  exact_callsite_bijection:true
}, null, 2));
