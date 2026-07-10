#!/usr/bin/env bash
# PostToolUse hook: пересобирает мозг сразу когда меняется память.
# Тихий, не валит сессию.

VAULT="/home/maior/pepe-vault"
MEM_SRC="/home/maior/.claude/projects/-home-maior/memory"

# Если запускался слишком недавно — пропускаем (защита от частых вызовов)
STAMP="/tmp/pepe-brain.last"
NOW=$(date +%s)
LAST=$(cat "$STAMP" 2>/dev/null || echo 0)
[ $((NOW - LAST)) -lt 2 ] && exit 0
echo "$NOW" > "$STAMP"

# Синкаем память Claude → vault (только если есть изменения в memory/)
if [ -d "$MEM_SRC" ] && [ -d "$VAULT/memory" ]; then
    if rsync -anc --delete --exclude='.git' "$MEM_SRC/" "$VAULT/memory/" 2>/dev/null | /usr/bin/grep -qE '^>|^c|^.f'; then
        rsync -a --delete --exclude='.git' "$MEM_SRC/" "$VAULT/memory/" 2>/dev/null
        [ -x "$VAULT/build_brain.py" ] && python3 "$VAULT/build_brain.py" >/dev/null 2>&1
        # инкрементальная пересборка семантического индекса (только изменённые файлы)
        [ -x "$VAULT/search_brain.py" ] && python3 "$VAULT/search_brain.py" --build >/dev/null 2>&1 &
        disown
    fi
fi
exit 0
