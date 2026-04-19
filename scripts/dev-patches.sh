#!/usr/bin/env bash
set -euo pipefail

FILE="/home/vscode/.vscode-server/extensions/marus25.cortex-debug-1.12.1/dist/debugadapter.js"
[ -f "$FILE" ] || exit 0

# Replace the two timeouts in the gdb-start block, anchored to the unique error string.
# Inner timeout (e.g. 10)  -> 2e3   Outer timeout (e.g. 5e3) -> 25e3
perl -0777 -i -pe '
    s|("Could not start gdb, no response from gdb".*?\}+\),?\s*)[\de]+(\),?\s*e\s*=\s*void\s*0\s*\}+\),?\s*)[\de]+(\);)|${1}2e3${2}25e3${3}|s
' "$FILE"

echo "Applied numeric-timeout patch to $FILE"

exit 0
