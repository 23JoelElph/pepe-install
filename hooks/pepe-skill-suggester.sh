#!/usr/bin/env bash
# PreToolUse hook: если tool_input содержит ключевые слова релевантных skills —
# добавляет reminder "у тебя есть skill X". Не блокирует, только warn.
set -e
INPUT=$(cat)

python3 - <<PYEOF
import json, sys, re, os
from pathlib import Path

try:
    data = json.loads('''$INPUT''')
except Exception:
    print("{}")
    sys.exit(0)

tool = data.get("tool_name", "")
inp = data.get("tool_input", {}) or {}

# Skill-suggester релевантен только для Bash / Edit / Write / MultiEdit
if tool not in ("Bash", "Edit", "Write", "MultiEdit"):
    print("{}"); sys.exit(0)

# rebuild index если старее 7 дней
INDEX = Path("/tmp/pepe-skills-index.json")
BUILD = Path.home() / "pepe-vault" / "scripts" / "skills" / "build-skills-index.py"
import time
if not INDEX.exists() or (time.time() - INDEX.stat().st_mtime > 7*86400):
    if BUILD.exists():
        os.system(f"python3 {BUILD} 2>/dev/null")

if not INDEX.exists():
    print("{}"); sys.exit(0)

try:
    idx = json.loads(INDEX.read_text())
except Exception:
    print("{}"); sys.exit(0)

# извлекаю ключевые слова из tool_input
haystack_parts = []
for k in ("command", "file_path", "content", "new_string", "old_string"):
    if k in inp: haystack_parts.append(str(inp[k])[:2000])
haystack = " ".join(haystack_parts).lower()

# для каждого skill — считаю сколько его keywords/tags попадают в haystack
scores = {}
for skill_name, info in idx.items():
    score = 0
    hits = []
    for kw in info.get("keywords", []):
        if kw and len(kw) > 3 and kw in haystack:
            score += 2
            hits.append(kw)
    for tag in info.get("tags", []):
        if tag and len(tag) > 3 and tag in haystack:
            score += 3
            hits.append(f"tag:{tag}")
    if score >= 6:  # threshold — иначе спам
        scores[skill_name] = (score, hits[:5], info.get("description","")[:120])

if not scores:
    print("{}"); sys.exit(0)

# топ-3 максимум
top = sorted(scores.items(), key=lambda kv: -kv[1][0])[:3]
lines = ["⚡ у тебя есть skills под эту задачу:"]
for name, (sc, hits, desc) in top:
    lines.append(f"  · **{name}** — {desc.strip()[:100]}  (match: {', '.join(hits[:3])})")
lines.append("  → используй Skill tool с одним из них, если задача им подходит.")
msg = "\\n".join(lines)

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "allow",
        "permissionDecisionReason": msg
    }
}, ensure_ascii=False))
PYEOF

exit 0
