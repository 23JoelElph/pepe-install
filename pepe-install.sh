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

# ═════ 5. banner + statusline + settings ═════════════
log "[5] PepeCode brand (banner, statusline, settings)"

# banner на .bashrc / .zshrc
BANNER_LINE="[ -f $INSTALL_DIR/files/pepe-banner.sh ] && bash $INSTALL_DIR/files/pepe-banner.sh"
for rc in "$REAL_HOME/.bashrc" "$REAL_HOME/.zshrc"; do
    [ -f "$rc" ] || continue
    grep -qF "pepe-banner.sh" "$rc" || echo -e "\n# PEPE CODE banner\n$BANNER_LINE" >> "$rc"
done
ok "banner подключён в .bashrc/.zshrc"

# statusline
sudo -u "$REAL_USER" cp "$INSTALL_DIR/files/statusline-pepe.sh" "$CLAUDE_DIR/statusline-pepe.sh"
sudo -u "$REAL_USER" chmod +x "$CLAUDE_DIR/statusline-pepe.sh"
ok "statusline установлен"

# settings.json (merge — не перетираем чужие настройки)
if [ ! -f "$CLAUDE_DIR/settings.json" ]; then
    sudo -u "$REAL_USER" cp "$INSTALL_DIR/files/settings.pepe.json" "$CLAUDE_DIR/settings.json"
    ok "settings.json создан"
else
    warn "settings.json уже есть — не перетираю. Смотри $INSTALL_DIR/files/settings.pepe.json для сверки."
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

# ═════ 7. cron: push 3× в день на GitHub ═════════════
log "[7] cron: push brain+memory 3× в день на GitHub"
CRON_TAG="# pepe-vault-sync-github"
(sudo -u "$REAL_USER" crontab -l 2>/dev/null | grep -v "$CRON_TAG"; \
 echo "0 9,15,22 * * * cd $VAULT_DIR && git push origin main >/dev/null 2>&1 $CRON_TAG") | \
    sudo -u "$REAL_USER" crontab -
ok "cron: 09:00 / 15:00 / 22:00 push → GitHub"

# ═════ финал ═════════════════════════════════════════
log "🐸 PEPE CODE установлен · $FRIEND_NAME"
ok "запусти новый терминал → увидишь PEPECODE banner"
ok "или сразу проверь: bash $INSTALL_DIR/files/pepe-banner.sh"
ok "команда: claude   (запустит Claude Code с PEPE-hooks)"
echo ""
printf "${V}welcome to PEPE CODE${R}, ${FRIEND_NAME}. 🐸\n"
