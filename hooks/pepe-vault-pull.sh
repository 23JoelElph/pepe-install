#!/usr/bin/env bash
# Подтягивает последнюю память из GitHub при старте сессии.
# Hook: SessionStart. Тихий.

VAULT="/home/maior/pepe-vault"
MEM_DST="/home/maior/.claude/projects/-home-maior/memory"

[ -d "$VAULT/.git" ] || exit 0

cd "$VAULT" || exit 0
git pull --rebase --autostash origin main >/dev/null 2>&1 || exit 0

if [ -d "$VAULT/memory" ]; then
    rsync -a --delete --exclude='.git' "$VAULT/memory/" "$MEM_DST/" 2>/dev/null
fi
exit 0
