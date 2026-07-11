#!/usr/bin/env bash
# PEPE диагностика для друга. Ничего не меняет — только смотрит.
# Запуск: bash <(curl -fsSL https://raw.githubusercontent.com/23JoelElph/pepe-install/main/pepe-diag.sh)

V="\033[1;38;2;199;125;255m"
G="\033[1;32m"; R="\033[0m"
sec() { printf "\n${V}═══ %s ═══${R}\n" "$*"; }

sec "1. Хост и юзер"
echo "hostname: $(hostname)"
echo "user:     $(whoami)"
echo "home:     $HOME"
echo "shell:    $SHELL"

sec "2. Claude Code"
which claude 2>&1
claude --version 2>&1 | head -3

sec "3. ~/.claude/ содержимое"
ls -la $HOME/.claude/ 2>&1 | head -25

sec "4. Скиллы/команды/агенты (счётчики)"
echo "skills:   $(ls -d $HOME/.claude/skills/*/ 2>/dev/null | wc -l)"
echo "commands: $(ls $HOME/.claude/commands/*.md 2>/dev/null | wc -l)"
echo "agents:   $(ls $HOME/.claude/agents/*.md 2>/dev/null | wc -l)"
echo "hooks:    $(ls $HOME/.claude/pepe-*.sh 2>/dev/null | wc -l)"

sec "5. settings.json (только hooks + statusLine)"
if [ -f $HOME/.claude/settings.json ]; then
    python3 -c "
import json
d = json.load(open('$HOME/.claude/settings.json'))
print('hooks:', list(d.get('hooks',{}).keys()))
for k, arr in d.get('hooks',{}).items():
    for e in arr:
        for h in e.get('hooks',[]):
            print(f'  {k}: {h.get(\"command\",\"\")[:80]}')
print('statusLine:', d.get('statusLine'))
print('theme:', d.get('theme'))
" 2>&1 | head -30
else
    echo "  ✗ ~/.claude/settings.json НЕТ"
fi

sec "6. ~/.claude.json (MCP)"
if [ -f $HOME/.claude.json ]; then
    python3 -c "
import json
d = json.load(open('$HOME/.claude.json'))
print('keys:', list(d.keys())[:10])
mcps = d.get('mcpServers', {})
print(f'mcpServers: {len(mcps)}')
for name in list(mcps.keys())[:15]:
    print(f'  · {name}')
" 2>&1
else
    echo "  ✗ ~/.claude.json НЕТ — MCP не сконфигурирован"
fi

sec "7. ~/pepe-vault"
if [ -d $HOME/pepe-vault ]; then
    ls -la $HOME/pepe-vault 2>&1 | head -12
    echo ""
    echo "memory файлов: $(ls $HOME/pepe-vault/memory/*.md 2>/dev/null | wc -l)"
    echo "user-molodoy.md есть?"
    [ -f $HOME/pepe-vault/memory/user-molodoy.md ] && echo "  ✓ да" || echo "  ✗ НЕТ"
    echo "MEMORY.md первые 5 строк:"
    head -5 $HOME/pepe-vault/memory/MEMORY.md 2>&1
    echo ""
    echo "git remote:"
    git -C $HOME/pepe-vault remote -v 2>&1 | head -3
    echo "git status:"
    git -C $HOME/pepe-vault status --short 2>&1 | head -5
else
    echo "  ✗ ~/pepe-vault НЕТ — vault не клонирован"
fi

sec "8. SSH-config (github-vault alias?)"
grep -A3 "Host github-vault" $HOME/.ssh/config 2>&1 || echo "  ✗ github-vault alias отсутствует"
echo ""
echo "ключи:"
ls $HOME/.ssh/id_pepe_* 2>&1 | head -3

sec "9. Тест SSH к github через наш alias"
if command -v ssh >/dev/null; then
    ssh -o BatchMode=yes -o ConnectTimeout=5 -T github-vault 2>&1 | head -3
fi

sec "10. Bashrc — есть ли banner-строка (не должно быть)"
grep -H "pepe-banner\|pepe-search" $HOME/.bashrc $HOME/.zshrc 2>&1 | head -5

sec "11. Cron"
crontab -l 2>&1 | head -10

sec "12. patch-pepe-bin.py применён к claude?"
CLAUDE_BIN=$(find $HOME/.npm-global -name claude.exe 2>/dev/null | head -1)
[ -z "$CLAUDE_BIN" ] && CLAUDE_BIN=$(readlink -f $(which claude 2>/dev/null))
echo "  бинарь: $CLAUDE_BIN"
if [ -f "$CLAUDE_BIN" ]; then
    if grep -aoE "Welcome to PEPE CODE" "$CLAUDE_BIN" >/dev/null 2>&1; then
        echo "  ✓ patched (Welcome to PEPE CODE присутствует)"
    else
        echo "  ✗ НЕ пропатчен (Welcome to Claude Code стандартный)"
    fi
    if grep -aoE 'H\.hookName," says: ",H\.content' "$CLAUDE_BIN" >/dev/null 2>&1; then
        echo "  ✗ H.hookName паттерн ЖИВОЙ — префикс SessionStart says: будет видно"
    fi
    if grep -aoE '[a-zA-Z]{1,2}\.hookName," says: ",[a-zA-Z]{1,2}\.content' "$CLAUDE_BIN" >/dev/null 2>&1; then
        found=$(grep -aoE '[a-zA-Z]{1,2}\.hookName," says: ",[a-zA-Z]{1,2}\.content' "$CLAUDE_BIN" | head -3)
        echo "  ✗ ЖИВЫЕ hookName-паттерны: $found"
    fi
fi

printf "\n${G}✓ diagnose done. Скопируй ВЕСЬ вывод сверху и пришли Molodoy.${R}\n"
