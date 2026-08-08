#!/usr/bin/env sh
# Print the SessionStart payload that carries the artifact-language rule.
#
# Deliberately just a `cat`. The JSON is built ahead of time by scripts/build.sh
# and committed as hooks/session-start.json, so this cannot fail on a machine
# without jq, and there is no runtime string-escaping to get wrong. If the
# payload is missing, cat exits non-zero and the failure is visible rather than
# producing malformed JSON the CLI would silently drop.
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
exec cat "$root/hooks/session-start.json"
