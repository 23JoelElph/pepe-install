#!/usr/bin/env bash
# Stop-hook: сырой session-dump + подготовка шаблона self-eval
# для следующей сессии (чтобы я его увидел и заполнил).
set -e
VAULT="/home/maior/pepe-vault"
RAG="$VAULT/_rag/sessions"
META="$VAULT/_meta"
mkdir -p "$RAG"

STAMP=$(date -Iseconds 2>/dev/null || date)
SLUG=$(date +%Y-%m-%dT%H-%M-%S 2>/dev/null || echo "session")
DUMP="$RAG/session-$SLUG.md"

# коммит + diff за 6ч + список изменённых файлов
cd "$VAULT" 2>/dev/null || exit 0
LAST_COMMIT=$(git log -1 --format="%h %s" 2>/dev/null | head -c 200)
CHANGED_FILES=$(git log --since="6 hours ago" --name-only --format="" 2>/dev/null | sort -u | grep -v '^$' | head -30 | tr '\n' ',' | sed 's/,/, /g')
COMMITS_6H=$(git log --since="6 hours ago" --format="- %s" 2>/dev/null | head -20)

cat > "$DUMP" <<END
---
name: session-$SLUG
title: "Session raw · $SLUG"
description: "Сырой лог закрытой сессии — commits, changed files, шаблон self-eval для следующей меня"
metadata:
  node_type: session
  type: reference
  hidden: true
---

# Session $STAMP

**Last commit:** $LAST_COMMIT

**Changed files (за 6ч):**
$CHANGED_FILES

**Commits:**
$COMMITS_6H

## Self-evaluation (не оценено — оценить в следующей сессии)

- [ ] Accuracy — правильно ли я понял задачу? Что я сделал не по делу?
- [ ] Completeness — что осталось незакрытым, а сказал "готово"?
- [ ] Clarity — где я жанрил "🎯 всё зелёное" вместо честного отчёта?
- [ ] Actionability — где я оставил брата без чётких следующих шагов?
- [ ] Conciseness — сколько лишних таблиц было? Сколько абзацев можно было не писать?

## Repair-loops в этой сессии

- [ ] Повторил ли я ошибку (тот же bash-эскейпинг, тот же timeout, тот же regex не сработал)?
- [ ] Если да — какую? Что не понял с первого раза?

## Skills — что применил / что должен был

- Что применил: (проставит skills-tracker)
- Что должен был но не применил: (заполнить руками при review)

END

# отмечаем что есть непроверенная сессия
touch "$META/.unreviewed-session"
echo "$SLUG" > "$META/.last-session-slug"

exit 0
