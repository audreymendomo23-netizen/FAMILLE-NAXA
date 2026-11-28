#!/usr/bin/env bash
# Dedicated GRILLAD runner; retry only plugin repository resolution failure.
set -euo pipefail
[[ "$GITHUB_ACTIONS" == true && "$GITHUB_REPOSITORY" == audreymendomo23-netizen/FAMILLE-NAXA && "$GITHUB_REF" == refs/heads/work/grillad-foundation-20261127 ]] || exit 2
for task in "$@"; do [[ "$task" == :grillad:* ]] || exit 2; done
[[ $# -gt 0 ]] || exit 2
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
if gradle --no-daemon --stacktrace "$@" 2>&1 | tee "$tmp/first.log"; then exit 0; fi
if ! grep -Eq "Plugin .* was not found|could not resolve plugin artifact" "$tmp/first.log"; then exit 1; fi
# Same artifact/version as the declared plugin, direct Maven resolution when marker unavailable.
# No edits to shared Gradle settings or version substitution.
cat > "$tmp/grillad-plugin.init.gradle" <<'GRADLE'
beforeSettings { s ->
 s.pluginManagement.resolutionStrategy.eachPlugin {
  if (requested.id.id == 'com.google.devtools.ksp' && requested.version == '2.0.20-1.0.25') {
   useModule("com.google.devtools.ksp:symbol-processing-gradle-plugin:2.0.20-1.0.25")
  }
 }
}
GRADLE
gradle --no-daemon --refresh-dependencies --stacktrace -I "$tmp/grillad-plugin.init.gradle" "$@"
