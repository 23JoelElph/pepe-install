#!/usr/bin/env bash
# PEPE CODE rebrand status line — purple themed
read -r -d '' INPUT < /dev/stdin || true

PARSED=$(printf '%s' "$INPUT" | python3 -c '
import json, sys, os
try:
    d = json.load(sys.stdin)
except Exception:
    d = {}
model = (d.get("model") or {}).get("display_name") or (d.get("model") or {}).get("id") or "claude"
ws = d.get("workspace") or {}
cwd = ws.get("current_dir") or d.get("cwd") or os.path.expanduser("~")
home = os.path.expanduser("~")
if cwd.startswith(home):
    cwd = "~" + cwd[len(home):]
print(model)
print(cwd)
' 2>/dev/null)
MODEL=$(printf '%s\n' "$PARSED" | sed -n '1p')
DIR=$(printf '%s\n' "$PARSED" | sed -n '2p')

[ -z "$MODEL" ] && MODEL="claude"
[ -z "$DIR" ]   && DIR="~"

E=$'\033'
BRIGHT="${E}[1;38;2;199;125;255m"
MED="${E}[38;2;155;89;182m"
DIM_P="${E}[38;2;138;108;188m"
DIM="${E}[2m"
RESET="${E}[0m"

printf "%b🐸 PEPE CODE%b %b│%b %b%s%b %b│%b %b%s%b" \
  "$BRIGHT" "$RESET" \
  "$MED" "$RESET" \
  "$DIM_P" "$MODEL" "$RESET" \
  "$MED" "$RESET" \
  "$DIM" "$DIR" "$RESET"
