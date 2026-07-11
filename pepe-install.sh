#!/usr/bin/env bash
# 🐸 PEPE CODE — установщик от Molodoy
#
# Ставит: OpenCode/Claude Code + hooks + skills + commands + agents + banner PepeCode.
# Синк vault: push 3× в день на GitHub + OPi (домашний сервер под контролем Molodoy).
#
# Использование:
#   curl -fsSL https://raw.githubusercontent.com/23JoelElph/pepe-install/main/pepe-install.sh | bash -s -- <твоё-имя>
# Или локально:
#   bash pepe-install.sh <твоё-имя>

set -e

# ═════ настройки ═════════════════════════════════════
GITHUB_USER="23JoelElph"
INSTALL_REPO="https://github.com/${GITHUB_USER}/pepe-install.git"
VAULT_REPO="https://github.com/${GITHUB_USER}/pepe-vault.git"       # приватный — нужен PAT
OPI_HOST="pepe-opi4a.tail905606.ts.net"                              # домашний сервер, Tailscale
OPI_USER="orangepi"

# ═════ параметр: имя друга ═══════════════════════════
FRIEND_NAME="${1:-}"
if [ -z "$FRIEND_NAME" ]; then
    if [ -t 0 ]; then
        printf "🐸 введи своё имя (formica, drug2, …): "
        read -r FRIEND_NAME
    else
        FRIEND_NAME="friend"
    fi
fi

# ═════ хелперы ═══════════════════════════════════════
V="\033[38;2;199;125;255m"      # фиолетовый PEPECODE
G="\033[38;2;107;231;131m"      # frog-зелёный
P="\033[38;2;255;122;192m"      # pink
R="\033[0m"
log() { printf "\n${V}═══${R} \033[1m%s${R}\n" "$*"; }
ok()  { printf "  ${G}✓${R} %s\n" "$*"; }
warn(){ printf "  ${P}!${R} %s\n" "$*"; }
skip(){ printf "  \033[2m·\033[0m %s\n" "$*"; }
err() { printf "  \033[1;31m✗${R} %s\n" "$*"; }

# ═════ real user (не root) ═══════════════════════════
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    REAL_USER="$SUDO_USER"; REAL_HOME="/home/$SUDO_USER"
elif [ "$(whoami)" != "root" ]; then
    REAL_USER="$(whoami)"; REAL_HOME="$HOME"
else
    REAL_USER="root"; REAL_HOME="/root"
fi

log "🐸 PEPE CODE установщик — $FRIEND_NAME"
ok "юзер: $REAL_USER · home: $REAL_HOME"
ok "GitHub: $GITHUB_USER"
ok "домашний сервер: $OPI_HOST"

# ═════ 1. базовые пакеты ═════════════════════════════
log "[1] проверка зависимостей"
NEED=""
for cmd in git curl python3 node npm; do
    command -v $cmd >/dev/null 2>&1 || NEED="$NEED $cmd"
done
if [ -n "$NEED" ]; then
    warn "ставлю:$NEED"
    if command -v sudo >/dev/null; then
        sudo apt-get update -qq
        [ -z "${NEED##* node*}" ] && curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo bash - >/dev/null 2>&1
        sudo apt-get install -y -qq git python3 python3-pip curl nodejs 2>&1 | tail -3
    else
        err "нужен sudo — доставь вручную:$NEED"
        exit 1
    fi
fi
ok "всё есть: git($(git --version | head -c 20)), python3($(python3 --version | cut -d' ' -f2)), node($(node -v))"

# ═════ 2. Claude Code / OpenCode ═════════════════════
log "[2] Claude Code"
if command -v claude >/dev/null 2>&1; then
    ok "claude уже установлен: $(claude --version 2>&1 | head -1)"
else
    warn "ставлю Claude Code"
    npm install -g @anthropic-ai/claude-code --force 2>&1 | tail -3
    ok "готово: $(claude --version 2>&1 | head -1)"
fi

# ═════ 3. клонирую pepe-install (публичный) ══════════
log "[3] pepe-install репозиторий"
INSTALL_DIR="$REAL_HOME/pepe-install"

# если существующий origin отличается — сносим и клонируем заново
if [ -d "$INSTALL_DIR/.git" ]; then
    CURRENT_ORIGIN=$(sudo -u "$REAL_USER" git -C "$INSTALL_DIR" remote get-url origin 2>/dev/null || echo "")
    if [ "$CURRENT_ORIGIN" != "$INSTALL_REPO" ]; then
        warn "старый ~/pepe-install (origin: $CURRENT_ORIGIN) — сношу и клонирую свежий"
        rm -rf "$INSTALL_DIR"
    fi
fi

if [ ! -d "$INSTALL_DIR/.git" ]; then
    sudo -u "$REAL_USER" git clone "$INSTALL_REPO" "$INSTALL_DIR" 2>&1 | tail -2
    ok "клонировано в $INSTALL_DIR"
else
    sudo -u "$REAL_USER" git -C "$INSTALL_DIR" pull 2>&1 | tail -2
    ok "обновлено (pull)"
fi

# ═════ 4. раскладка skills/agents/commands/hooks ═════
log "[4] раскладка в ~/.claude"
CLAUDE_DIR="$REAL_HOME/.claude"
sudo -u "$REAL_USER" mkdir -p "$CLAUDE_DIR"/{skills,commands,agents}

# skills
sudo -u "$REAL_USER" cp -rn "$INSTALL_DIR/skills"/* "$CLAUDE_DIR/skills/" 2>/dev/null || true
SKILLS_N=$(ls -d "$CLAUDE_DIR/skills"/*/ 2>/dev/null | wc -l)
ok "skills: $SKILLS_N"

# commands
sudo -u "$REAL_USER" cp -n "$INSTALL_DIR/commands"/*.md "$CLAUDE_DIR/commands/" 2>/dev/null || true
CMDS_N=$(ls "$CLAUDE_DIR/commands"/*.md 2>/dev/null | wc -l)
ok "commands: $CMDS_N"

# agents
sudo -u "$REAL_USER" cp -n "$INSTALL_DIR/agents"/*.md "$CLAUDE_DIR/agents/" 2>/dev/null || true
AGENTS_N=$(ls "$CLAUDE_DIR/agents"/*.md 2>/dev/null | wc -l)
ok "agents: $AGENTS_N"

# hooks
for h in "$INSTALL_DIR/hooks"/*.sh; do
    [ -f "$h" ] || continue
    dest="$CLAUDE_DIR/$(basename $h)"
    sudo -u "$REAL_USER" cp -n "$h" "$dest"
    sudo -u "$REAL_USER" chmod +x "$dest"
done
HOOKS_N=$(ls "$CLAUDE_DIR"/pepe-*.sh 2>/dev/null | wc -l)
ok "hooks: $HOOKS_N"

# ═════ 5. brand: art, banner, statusline, patch ═════
log "[5] PepeCode brand (art, banner, statusline, patch)"

# Убираем строку banner из bashrc/zshrc (banner только при claude)
for rc in "$REAL_HOME/.bashrc" "$REAL_HOME/.zshrc"; do
    [ -f "$rc" ] || continue
    if grep -q "pepe-banner.sh" "$rc"; then
        sudo -u "$REAL_USER" cp "$rc" "${rc}.pre-pepe-bashrc-cleanup.bak"
        sudo -u "$REAL_USER" sed -i '/# PEPE CODE banner/d; /pepe-banner\.sh/d' "$rc"
        ok "$(basename $rc): banner-строка убрана"
    fi
done

# Копируем ассеты в ~/.claude/
for asset in pepe-art.txt pepe-banner.sh statusline-pepe.sh patch-pepe-bin.py; do
    sudo -u "$REAL_USER" cp "$INSTALL_DIR/files/$asset" "$CLAUDE_DIR/$asset"
done
sudo -u "$REAL_USER" chmod +x "$CLAUDE_DIR/pepe-banner.sh" "$CLAUDE_DIR/statusline-pepe.sh" "$CLAUDE_DIR/patch-pepe-bin.py"
ok "ассеты: pepe-art.txt · pepe-banner.sh · statusline-pepe.sh · patch-pepe-bin.py"

# settings.json — всегда актуализируем (с бэкапом старого)
if [ -f "$CLAUDE_DIR/settings.json" ]; then
    sudo -u "$REAL_USER" cp "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR/settings.json.pre-pepe.bak"
    ok "старый settings.json → settings.json.pre-pepe.bak"
fi
sudo -u "$REAL_USER" sed "s|__HOME__|$REAL_HOME|g" \
    "$INSTALL_DIR/files/settings.pepe.json" > "$CLAUDE_DIR/settings.json"
sudo -u "$REAL_USER" chown "$REAL_USER:$REAL_USER" "$CLAUDE_DIR/settings.json"
ok "settings.json обновлён (все PEPE-хуки + фиолетовый statusline)"

# Патч бинарника claude — убирает "SessionStart:startup says:" префикс перед баннером
CLAUDE_BIN=$(which claude 2>/dev/null || echo "")
if [ -n "$CLAUDE_BIN" ] && [ -f "$CLAUDE_BIN" ]; then
    if sudo -u "$REAL_USER" python3 "$CLAUDE_DIR/patch-pepe-bin.py" 2>&1 | tail -2; then
        ok "бинарь claude пропатчен — префикс SessionStart убран"
    else
        warn "patch не удался — запусти вручную: python3 ~/.claude/patch-pepe-bin.py"
    fi
else
    warn "claude бинарь не найден — patch пропущен (переустанови pepe-install после npm install)"
fi

# ═════ 6. vault — клонируется с GitHub через deploy-key ═══
log "[6] pepe-vault — приватный репозиторий на GitHub"
VAULT_DIR="$REAL_HOME/pepe-vault"

# Генерируем персональный SSH-ключ (если ещё нет)
SSH_DIR="$REAL_HOME/.ssh"
KEY="$SSH_DIR/id_pepe_${FRIEND_NAME}"
sudo -u "$REAL_USER" mkdir -p "$SSH_DIR"
sudo -u "$REAL_USER" chmod 700 "$SSH_DIR"

if [ ! -f "$KEY" ]; then
    sudo -u "$REAL_USER" ssh-keygen -t ed25519 -f "$KEY" -N '' \
        -C "${FRIEND_NAME}@pepe-$(date +%Y-%m-%d)" >/dev/null 2>&1
    ok "SSH-ключ сгенерирован: $KEY"
fi

# SSH-config: github-vault → использовать этот ключ
if ! grep -q "Host github-vault" "$SSH_DIR/config" 2>/dev/null; then
    sudo -u "$REAL_USER" tee -a "$SSH_DIR/config" >/dev/null <<SSHCFG

Host github-vault
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_pepe_${FRIEND_NAME}
    IdentitiesOnly yes
    StrictHostKeyChecking accept-new
SSHCFG
    ok "SSH-config: alias github-vault → github.com"
fi

# Пробуем клонировать
VAULT_URL="git@github-vault:${GITHUB_USER}/pepe-vault.git"
if [ -d "$VAULT_DIR/.git" ]; then
    sudo -u "$REAL_USER" git -C "$VAULT_DIR" pull 2>&1 | tail -2 || \
        warn "pull упал — возможно ключ ещё не добавлен на GitHub"
else
    if sudo -u "$REAL_USER" git clone "$VAULT_URL" "$VAULT_DIR" 2>&1 | tail -3; then
        ok "vault клонирован"
    else
        # Ключ ещё не добавлен на GitHub — показываем инструкцию
        PUB=$(cat "$KEY.pub")
        echo ""
        printf "  ${P}════════════════════════════════════════════════════════${R}\n"
        printf "  ${P}!  Ключ ещё не добавлен на GitHub. Инструкция:${R}\n"
        printf "  ${P}════════════════════════════════════════════════════════${R}\n\n"
        echo "  1. Скопируй свой ПУБЛИЧНЫЙ ключ (одна строка снизу):"
        echo ""
        printf "  ${G}${PUB}${R}\n\n"
        echo "  2. Отправь его Molodoy — он добавит за 30 секунд на:"
        echo "     https://github.com/${GITHUB_USER}/pepe-vault/settings/keys/new"
        echo "     • Title: ${FRIEND_NAME}-$(date +%Y-%m-%d)"
        echo "     • Key: (вставь публичный)"
        echo "     • ✓ Allow write access"
        echo ""
        echo "  3. Дождись подтверждения и запусти установщик снова:"
        printf "     ${V}bash ~/pepe-install/pepe-install.sh ${FRIEND_NAME}${R}\n"
        echo ""
        printf "  ${P}════════════════════════════════════════════════════════${R}\n"
    fi
fi

# ═════ 7. MCP серверы (наш набор + OSINT) ═════════════
log "[7] MCP серверы"
if [ -f "$REAL_HOME/.claude.json" ]; then
    sudo -u "$REAL_USER" python3 <<PYEOF
import json, os
p = "$REAL_HOME/.claude.json"
d = json.load(open(p))
if 'mcpServers' not in d:
    d['mcpServers'] = {}

# Наш набор: универсальные + сильные для реверса / OSINT / разработки
OUR_MCPS = {
    # актуальные docs библиотек — must-have для разработки
    "context7": {"type": "http", "url": "https://mcp.context7.com/mcp"},
    # явное chain-of-thought для сложных задач
    "sequential-thinking": {"command": "npx", "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]},
    # персистентная память между разговорами
    "memory": {"command": "npx", "args": ["-y", "@modelcontextprotocol/server-memory"]},
    # headless-браузер (recon, скраппинг, отчёты)
    "playwright": {"command": "npx", "args": ["-y", "@playwright/mcp@latest"]},
}

added = []
for name, cfg in OUR_MCPS.items():
    if name not in d['mcpServers']:
        d['mcpServers'][name] = cfg
        added.append(name)

json.dump(d, open(p, 'w'), indent=2, ensure_ascii=False)
print(f'  ✓ добавлено: {added}' if added else '  · всё было')
print(f'  всего MCP: {len(d["mcpServers"])}')
PYEOF
    ok "MCP настроены"
else
    warn "~/.claude.json ещё нет — MCP пропущены (запусти claude один раз, потом pepe-fix.sh)"
fi

# ═════ 8. cron: pull-rebase + push 3× в день ═════════
log "[8] cron: 3× в день pull+push (safe, не потеряет локальное)"
CRON_TAG="# pepe-vault-sync-github"
(sudo -u "$REAL_USER" crontab -l 2>/dev/null | grep -v "$CRON_TAG"; \
 echo "0 9,15,22 * * * cd $VAULT_DIR && git pull --rebase --autostash origin main && git push origin main >/dev/null 2>&1 $CRON_TAG") | \
    sudo -u "$REAL_USER" crontab -
ok "cron: 09:00 / 15:00 / 22:00 pull-rebase + push → GitHub"

# ═════ 9. Persistent friend memory (кто такой friend + Molodoy) ═════
log "[9] персональная память друга: memory/user-${FRIEND_NAME}.md"
FRIEND_MEM="$VAULT_DIR/memory/user-${FRIEND_NAME}.md"
if [ -d "$VAULT_DIR" ] && [ ! -f "$FRIEND_MEM" ]; then
    sudo -u "$REAL_USER" tee "$FRIEND_MEM" >/dev/null <<EOF
---
name: user-${FRIEND_NAME}
description: "Личная заметка ${FRIEND_NAME} — базовый шаблон, дополняй по мере знакомства"
metadata:
  node_type: memory
  type: user
---

# ${FRIEND_NAME}

**Роль:** пользователь PEPE (друг Molodoy)

**Заметка:** это твой личный файл. Дополняй его — я буду читать при старте каждой сессии.
Например: «моя основная задача — реверс UAV-плат», «люблю кириллические комменты», и т.д.

**Обращение:** узнаю по мере общения.

**Связано:** [[user-molodoy]], [[pepe-lore]]
EOF
    ok "создан $(basename $FRIEND_MEM)"
fi

# ═════ финал ═════════════════════════════════════════
log "🐸 PEPE CODE установлен · $FRIEND_NAME"
ok "запусти новый терминал → увидишь PEPECODE banner"
ok "или сразу проверь: bash $INSTALL_DIR/files/pepe-banner.sh"
ok "команда: claude   (запустит Claude Code с PEPE-hooks)"
echo ""
printf "${V}welcome to PEPE CODE${R}, ${FRIEND_NAME}. 🐸\n"
