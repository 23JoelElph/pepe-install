#!/usr/bin/env bash
# 🐸 PEPE FIX v2 — БЕЗОПАСНЫЙ ремонт после первой установки.
# НИКАКОГО reset --hard. Все локальные изменения сохраняются через git stash.

set -e

V="\033[1;38;2;199;125;255m"
G="\033[1;32m"; Y="\033[1;33m"; R="\033[0m"
sec() { printf "\n${V}═══ %s ═══${R}\n" "$*"; }
ok()   { printf "  ${G}✓${R} %s\n" "$*"; }
warn() { printf "  ${Y}!${R} %s\n" "$*"; }

sec "1/7 — cron: заменяю push на pull-rebase-и-push (не потеряет локальное)"
CRON_TAG="# pepe-vault-sync-github"
(crontab -l 2>/dev/null | grep -v "$CRON_TAG"; \
 echo "0 9,15,22 * * * cd \$HOME/pepe-vault && git pull --rebase --autostash origin main && git push origin main >/dev/null 2>&1 $CRON_TAG") | crontab -
ok "cron: pull --rebase --autostash + push"

sec "2/7 — vault: pull без потери твоих файлов (git stash при конфликте)"
VAULT=$HOME/pepe-vault
if [ ! -d "$VAULT/.git" ]; then
    warn "vault отсутствует — клонирую"
    git clone git@github-vault:23JoelElph/pepe-vault.git "$VAULT" 2>&1 | tail -3
else
    cd "$VAULT"
    # Сохраняю всё что не committed — если есть локальные изменения
    if ! git diff --quiet || ! git diff --cached --quiet; then
        git -c user.name="PEPE" -c user.email="pepe@local" \
            stash push -u -m "pepe-fix backup $(date -Iseconds)" 2>&1 | tail -1
        warn "твои локальные изменения → git stash (восстанови: git stash pop)"
    fi
    git fetch origin main 2>&1 | tail -1
    git pull --rebase --autostash origin main 2>&1 | tail -3 || {
        warn "pull-rebase упал, что-то нужно решить руками"
    }
    ok "vault sync · $(ls memory/*.md 2>/dev/null | wc -l) memory-файлов"
fi

sec "3/7 — обязательно должны быть на месте (тяну явно если нет)"
for f in memory/user-molodoy.md memory/MEMORY.md _meta/startup.md; do
    if [ ! -f "$VAULT/$f" ]; then
        cd "$VAULT" && git checkout origin/main -- "$f" 2>&1 | tail -1 && \
            ok "$f восстановлен"
    fi
done

sec "4/7 — pull свежий pepe-install"
cd $HOME/pepe-install
git pull 2>&1 | tail -2
ok "pepe-install свежий"

sec "5/7 — patch-pepe-bin.py: обновляю + репатчу claude.exe"
cp $HOME/pepe-install/files/patch-pepe-bin.py $HOME/.claude/patch-pepe-bin.py
chmod +x $HOME/.claude/patch-pepe-bin.py
CLAUDE_BIN=$HOME/.npm-global/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe
BAK=$HOME/.claude/claude.exe.bak
[ -f "$BAK" ] && cp "$BAK" "$CLAUDE_BIN" && ok "restored оригинал"
python3 $HOME/.claude/patch-pepe-bin.py 2>&1 | tail -6

sec "6/7 — MCP серверы (context7 минимум, остальные — если не установлены)"
if [ -f $HOME/.claude.json ]; then
    python3 <<'PYEOF'
import json, os
p = os.path.expanduser('~/.claude.json')
d = json.load(open(p))
if 'mcpServers' not in d:
    d['mcpServers'] = {}

# Минимальный набор — работает без ключей
DEFAULT_MCPS = {
    "context7": {
        "type": "http",
        "url": "https://mcp.context7.com/mcp"
    },
    "sequential-thinking": {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
    },
    "memory": {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-memory"]
    }
}

added = []
for name, cfg in DEFAULT_MCPS.items():
    if name not in d['mcpServers']:
        d['mcpServers'][name] = cfg
        added.append(name)

json.dump(d, open(p, 'w'), indent=2, ensure_ascii=False)
print(f'  добавлено: {added}' if added else '  · всё уже было')
print(f'  всего MCP: {len(d["mcpServers"])}')
PYEOF
else
    warn "~/.claude.json нет — создам через первый запуск claude"
fi

sec "7/7 — верификация"
echo "vault:  $(ls $VAULT/memory/*.md 2>/dev/null | wc -l) memory-файлов"
echo "MCP:    $(python3 -c "import json; print(len(json.load(open('$HOME/.claude.json',encoding='utf-8')).get('mcpServers',{})))" 2>/dev/null)"
[ -f $VAULT/memory/user-molodoy.md ] && ok "user-molodoy.md на месте" || warn "user-molodoy.md ✗"
[ -f $VAULT/_meta/startup.md ] && ok "_meta/startup.md на месте" || warn "startup.md ✗"

printf "\n${G}✓ FIX завершён.${R}\n"
echo ""
echo "Теперь:"
echo "  1. открой новый терминал"
echo "  2. cd ~/pepe-vault && claude"
echo "  3. спроси: кто такой Molodoy?"
echo ""
echo "Если хочешь чтобы claude запускался всегда в vault:"
echo "  echo \"alias claude='cd ~/pepe-vault && claude'\" >> ~/.zshrc && source ~/.zshrc"
