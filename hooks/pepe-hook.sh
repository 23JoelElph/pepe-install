#!/usr/bin/env bash
# SessionStart hook: emit the Pepe banner as systemMessage.
# The hookName + " says: " prefix is stripped by a binary patch
# (see ~/.claude/patch-pepe-bin.py), so the banner renders cleanly.
set -e
BANNER=$("$HOME/.claude/pepe-banner.sh" 2>/dev/null || true)
python3 -c '
import json, sys
banner = sys.stdin.read()
print(json.dumps({"systemMessage": banner}))
' <<< "$BANNER"
