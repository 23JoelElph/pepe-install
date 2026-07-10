#!/usr/bin/env bash
# Синкает память Claude → pepe-vault и пушит в GitHub.
# Hook: Stop / SessionEnd. Тихий, не валит сессию.

set -e
VAULT="/home/maior/pepe-vault"
MEM_SRC="/home/maior/.claude/projects/-home-maior/memory"

[ -d "$VAULT/.git" ] || exit 0
[ -d "$MEM_SRC" ] || exit 0

mkdir -p "$VAULT/memory"
# Двусторонняя синхронизация:
# 1. Файлы которые есть в auto-memory но не в vault → добавляем в vault
# 2. Файлы которые есть в vault но не в auto-memory → добавляем в auto-memory (не удаляем!)
# 3. Файлы что есть в обоих — тот у которого mtime новее выигрывает
# rsync без --delete чтобы не сносить руками созданные заметки
rsync -au --exclude='.git' --exclude='MEMORY.md' "$MEM_SRC/" "$VAULT/memory/" 2>/dev/null || exit 0
rsync -au --exclude='.git' --exclude='MEMORY.md' "$VAULT/memory/" "$MEM_SRC/" 2>/dev/null || true

cd "$VAULT" || exit 0

# пересборка мозга если есть build-скрипт (не валим сессию если упало)
[ -x "$VAULT/build_brain.py" ] && python3 "$VAULT/build_brain.py" >/dev/null 2>&1 || true

if git diff --quiet && git diff --cached --quiet; then
    exit 0
fi

# ── _meta/last_session.md: свежий hint для следующей сессии ──────
# ВАЖНО: делаем ДО commit, чтобы этот файл вошёл в тот же коммит.
# Кто менял, что менял, когда — коротко, чтобы SessionStart hook подхватил.
META="$VAULT/_meta"
if [ -d "$META" ]; then
    STAMP=$(date -Iseconds 2>/dev/null || date)
    LAST_COMMIT=$(cd "$VAULT" && git log -1 --format="%h %s" 2>/dev/null | head -c 200)
    CHANGED=$(cd "$VAULT" && git diff --stat HEAD~1 HEAD 2>/dev/null | tail -1 | head -c 200)
    LAST_LOG=$(cd "$VAULT" && git log --since="6 hours ago" --format="- %s" 2>/dev/null | head -8)

    {
        echo ""
        echo "## Session $STAMP"
        echo ""
        echo "**last commit:** $LAST_COMMIT"
        echo "**diff:** $CHANGED"
        echo ""
        echo "**commits за 6ч:**"
        echo "$LAST_LOG"
    } >> "$META/last_session.md.tmp"

    # ротация: держим только последние 3 Session-блока
    if [ -f "$META/last_session.md" ]; then
        # берём первую строку title и первые 3 ## Session блока
        awk '
            /^# / && !title { print; title=1; next }
            /^## Session / { block++ }
            block <= 3 { print }
        ' "$META/last_session.md" > "$META/last_session.md.keep" 2>/dev/null || true
        # если нет — берём как есть
        [ -s "$META/last_session.md.keep" ] || cp "$META/last_session.md" "$META/last_session.md.keep"
    else
        echo "# Последняя сессия" > "$META/last_session.md.keep"
    fi

    # склеиваем: keep + новый блок
    cat "$META/last_session.md.keep" "$META/last_session.md.tmp" > "$META/last_session.md"
    rm -f "$META/last_session.md.keep" "$META/last_session.md.tmp"
fi

# ── commit + push ────────────────────────────────────────────────
HOST=$(hostname)
git add -A >/dev/null 2>&1
git commit -m "session sync · $HOST · $(date -Iseconds)" >/dev/null 2>&1 || exit 0
git push origin main >/dev/null 2>&1 &
GIT_SSH_COMMAND="/usr/bin/ssh -i /home/maior/.ssh/id_pepe_opi4a -o StrictHostKeyChecking=no" git push opi main >/dev/null 2>&1 &
disown
exit 0
