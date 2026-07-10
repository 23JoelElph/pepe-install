#!/usr/bin/env bash
# PostToolUse hook: считает какие skills применились (через Skill tool).
# Пишет в /tmp/pepe-skills-usage.json — cron еженедельно ротирует.
set -e
INPUT=$(cat)

python3 - <<PYEOF
import json, os
from pathlib import Path

try:
    data = json.loads('''$INPUT''')
except Exception:
    exit(0)

tool = data.get("tool_name", "")
if tool != "Skill":
    exit(0)

inp = data.get("tool_input", {}) or {}
skill = inp.get("skill", "")
if not skill:
    exit(0)

USAGE = Path("/tmp/pepe-skills-usage.json")
try:
    stats = json.loads(USAGE.read_text()) if USAGE.exists() else {}
except Exception:
    stats = {}

stats[skill] = stats.get(skill, 0) + 1
USAGE.write_text(json.dumps(stats, indent=2, ensure_ascii=False))
PYEOF

exit 0
