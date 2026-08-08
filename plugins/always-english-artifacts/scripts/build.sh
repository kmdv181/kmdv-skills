#!/usr/bin/env sh
# Regenerate hooks/session-start.json from rules/artifact-language.md.
#
# Run this after editing the rule, then commit both files. Needs jq, but only
# here — the hook itself has no dependencies. scripts/test.sh fails if the two
# files have drifted apart, so forgetting to run this is caught.
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

command -v jq >/dev/null 2>&1 || {
  echo "build.sh needs jq" >&2
  exit 1
}

jq -Rs '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:.}}' \
  <"$root/rules/artifact-language.md" >"$root/hooks/session-start.json"

echo "wrote hooks/session-start.json"
