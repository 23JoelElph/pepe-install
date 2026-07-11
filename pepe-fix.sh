#!/usr/bin/env bash
# 🐸 PEPE FIX — точечный ремонт после первой установки.
# Устраняет: пустой vault, устаревший patch-pepe-bin.py, отсутствие MCP context7.

set -e

V="\033[1;38;2;199;125;255m"
G="\033[1;32m"; Y="\033[1;33m"; R="\033[0m"
sec() { printf "\n${V}═══ %s ═══${R}\n" "$*"; }
ok() { printf "  ${G}✓${R} %s\n" "$*"; }
warn() { printf "  ${Y}!${R} %s\n" "$*"; }

sec "1/6 — стопорю cron pepe-sync (защита GitHub от deletions)"
if crontab -l 2>/dev/null | grep -q pepe-vault; then
    crontab -l | grep -v "pepe-vault" | crontab -
    ok "cron pepe-vault-sync отключён"
else
    ok "cron чистый"
fi

sec "2/6 — восстанавливаю vault с GitHub (жёстко)"
VAULT=$HOME/pepe-vault
if [ -d "$VAULT/.git" ]; then
    cd "$VAULT"
    git fetch origin main 2>&1 | tail -1
    git reset --hard origin/main 2>&1 | tail -1
    git clean -fdx 2>&1 | tail -3
    ok "vault sync с GitHub · $(ls memory/*.md 2>/dev/null | wc -l) memory-файлов"
else
    warn "vault отсутствует — клонирую"
    git clone git@github-vault:23JoelElph/pepe-vault.git "$VAULT" 2>&1 | tail -3
fi

sec "3/6 — pull свежий pepe-install (patch с universal-regex)"
cd $HOME/pepe-install
git pull 2>&1 | tail -2
ok "pepe-install свежий"

sec "4/6 — обновляю patch-pepe-bin.py и репатчу claude.exe"
cp $HOME/pepe-install/files/patch-pepe-bin.py $HOME/.claude/patch-pepe-bin.py
chmod +x $HOME/.claude/patch-pepe-bin.py

# восстанавливаю оригинал из бэкапа (patch делал бэкап)
CLAUDE_BIN=$HOME/.npm-global/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe
BAK=$HOME/.claude/claude.exe.bak
if [ -f "$BAK" ]; then
    cp "$BAK" "$CLAUDE_BIN"
    ok "restored оригинал из $BAK"
fi

python3 $HOME/.claude/patch-pepe-bin.py 2>&1 | tail -8

sec "5/6 — добавляю MCP context7 в ~/.claude.json"
if [ -f $HOME/.claude.json ]; then
    python3 <<'PYEOF'
import json, os
p = os.path.expanduser('~/.claude.json')
d = json.load(open(p))
if 'mcpServers' not in d:
    d['mcpServers'] = {}
if 'context7' not in d['mcpServers']:
    d['mcpServers']['context7'] = {
        "type": "sse",
        "url": "https://mcp.context7.com/sse"
    }
    json.dump(d, open(p, 'w'), indent=2, ensure_ascii=False)
    print(f'  ✓ добавлен context7')
else:
    print(f'  · context7 уже был')
print(f'  всего MCP: {len(d["mcpServers"])}')
PYEOF
else
    warn "~/.claude.json нет — MCP пропущен"
fi

sec "6/6 — верификация"
echo "vault: $(ls $VAULT/memory/*.md 2>/dev/null | wc -l) memory-файлов"
[ -f $VAULT/memory/user-molodoy.md ] && ok "user-molodoy.md на месте" || warn "user-molodoy.md отсутствует"
[ -f $VAULT/memory/friends-formica.md ] && ok "friends-formica.md на месте" || warn "friends-formica.md отсутствует"

echo ""
echo "MCP: $(python3 -c "import json; print(len(json.load(open('$HOME/.claude.json',encoding='utf-8')).get('mcpServers',{})))" 2>/dev/null || echo '?')"

# восстанавливаю cron (после того как vault восстановлен)
CRON_TAG="# pepe-vault-sync-github"
(crontab -l 2>/dev/null | grep -v "$CRON_TAG"; echo "0 9,15,22 * * * cd $VAULT && git pull --rebase origin main && git push origin main >/dev/null 2>&1 $CRON_TAG") | crontab -
ok "cron восстановлен (с pull --rebase перед push — чтоб не удалить GitHub-файлы)"

printf "\n${G}✓ FIX завершён.${R}\n"
echo ""
echo "Теперь:"
echo "  1. закрой все терминалы"
echo "  2. открой новый"
echo "  3. запусти:  claude"
echo "  4. спроси у него:  кто такой Molodoy?"
