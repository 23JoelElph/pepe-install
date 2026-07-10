#!/usr/bin/env bash
# SessionStart hook: инжектит контекст _meta/ в мой промпт (СКРЫТО от UI).
set -e
VAULT="/home/maior/pepe-vault"
META="$VAULT/_meta"
[ -d "$META" ] || exit 0

python3 - <<'PYEOF'
import json
from pathlib import Path
META = Path("/home/maior/pepe-vault/_meta")
parts = []

# 1) startup
p = META / "startup.md"
if p.is_file():
    parts.append("═══ PEPE STARTUP BRIEF ═══\n" + p.read_text(encoding="utf-8", errors="replace").strip())

# 2) mistakes — активная секция
p = META / "mistakes.md"
if p.is_file():
    txt = p.read_text(encoding="utf-8", errors="replace")
    # берём Активные до "## Устранённые"
    end = txt.find("## Устранённые")
    active = txt[:end].strip() if end > 0 else txt.strip()
    if active:
        parts.append("═══ MISTAKES · активные ═══\n" + active)

# 3) last_session — последний блок
p = META / "last_session.md"
if p.is_file():
    lines = p.read_text(encoding="utf-8", errors="replace").splitlines()
    last_start = 0
    for i, line in enumerate(lines):
        if line.startswith("## Session"):
            last_start = i
    tail = "\n".join(lines[last_start:last_start+100]).strip()
    if tail:
        parts.append("═══ ЧТО БЫЛО В ПРОШЛЫЙ РАЗ ═══\n" + tail)

# 4) unreviewed-session маркер
unreviewed = META / ".unreviewed-session"
if unreviewed.is_file():
    slug_file = META / ".last-session-slug"
    slug = slug_file.read_text().strip() if slug_file.is_file() else "?"
    parts.append(f"═══ ⚠ ПРЕДЫДУЩАЯ СЕССИЯ НЕ SELF-EVAL'НУТА ═══\nСырой дамп: _rag/sessions/session-{slug}.md\nПеред новой работой — прочитать шаблон, заполнить 5 осей.\nПосле — удалить: rm _meta/.unreviewed-session")

# 5) promises — active
p = META / "promises.md"
if p.is_file():
    txt = p.read_text(encoding="utf-8", errors="replace")
    end = min((txt.find(m) for m in ("## Отложены", "## Выполнено") if txt.find(m) > 0), default=len(txt))
    active = txt[:end].strip()
    if active and "пусто" not in active.lower():
        parts.append("═══ ВИСЯЩИЕ ОБЕЩАНИЯ ═══\n" + active)

# 6) skills-usage за последний период — если есть, показать что не применялось
usage_file = Path("/tmp/pepe-skills-usage.json")
if usage_file.is_file():
    try:
        stats = json.loads(usage_file.read_text())
        top5 = sorted(stats.items(), key=lambda x: -x[1])[:5]
        parts.append("═══ SKILLS · какие я реально применял ═══\n" + "\n".join(f"  {v}x  {k}" for k, v in top5) +
                     "\n(Остальные 60+ skills — не применялись. Либо начну применять, либо удалю через месяц.)")
    except Exception:
        pass

if parts:
    ctx = "\n\n".join(parts) + "\n\n🐸 Прочитай ПЕРЕД ответом. Правило формата: макс 3 таблицы, без 🎯-жаны."
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": ctx
        }
    }, ensure_ascii=False))
PYEOF
