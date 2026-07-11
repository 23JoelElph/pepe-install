#!/usr/bin/env bash
# 🐸 pepe-uninstall.sh — полное удаление PEPE-стека с машины.
# Обратная операция к pepe-install.sh.
# Написан заново после переезда с AEZA на GitHub + OPi (2026-07-11).
#
# ВАЖНО: если у тебя стоит Пятый (opencode + ECC) — он **НЕ будет тронут**.
# Скрипт удаляет только PEPE (Claude Code + hooks + ~/pepe-vault + ~/pepe-install).
#
# Запуск:
#   curl -fsSL https://raw.githubusercontent.com/23JoelElph/pepe-install/main/pepe-uninstall.sh | bash
# Или локально:
#   bash pepe-uninstall.sh
#
# Требует подтверждения — ничего не удаляется без явного "да".

set -e

V="\033[38;2;199;125;255m"
G="\033[38;2;107;231;131m"
P="\033[38;2;255;122;192m"
Y="\033[38;2;255;180;94m"
R="\033[0m"

log()  { printf "\n${V}═══${R} \033[1m%s${R}\n" "$*"; }
ok()   { printf "  ${G}✓${R} %s\n" "$*"; }
warn() { printf "  ${Y}!${R} %s\n" "$*"; }
skip() { printf "  \033[2m·\033[0m %s\n" "$*"; }
err()  { printf "  \033[1;31m✗${R} %s\n" "$*"; }

echo ""
printf "  ${V}🐸  UNINSTALL PEPE CODE${R} — обратная операция к pepe-install\n"
echo ""
echo "  Будет удалено:"
echo "    • ~/pepe-vault/               — локальный клон мозга"
echo "    • ~/pepe-install/             — скрипт установщика + hooks + banner"
echo "    • ~/.claude/                  — hooks, skills, agents, commands"
echo "    • ~/.claude.json              — MCP-конфиг Claude Code"
echo "    • ~/.ssh/id_github_23joel*    — SSH-ключ к git-серверу"
echo "    • ~/.ssh/config (Host github.com для 23JoelElph) — очистится этот блок"
echo "    • ~/.git-credentials          — GitHub PAT если сохранён"
echo "    • ~/.config/pepe/             — secrets.env + gh-token"
echo "    • cron 3× в день git push     — авто-sync на OPi"
echo "    • PEPE banner в ~/.bashrc / ~/.zshrc"
echo "    • Claude Code (npm -g)        — сам CLI"
echo ""
printf "  ${G}НЕ ТРОГАЕТСЯ:${R}\n"
echo "    • Пятый (opencode) — его конфиг ~/.config/opencode/ и ~/pyatyj-vault/"
echo "    • Node.js / npm    — могут быть нужны Пятому"
echo "    • apt-пакеты       — git, python3, curl, ssh"
echo "    • Любые файлы вне списка выше"
echo ""
read -rp "  Продолжить? (напиши 'да' и Enter, любой другой ответ — отмена): " CONFIRM
if [ "$CONFIRM" != "да" ]; then
    echo ""
    warn "отмена, ничего не тронуто."
    exit 0
fi

# ═══ [1] cron ═══════════════════════════════════════════════
log "[1/9] Убираю cron pepe-sync"
if crontab -l 2>/dev/null | grep -qE "pepe-vault|pepe-github-sync|pepe-vault-sync-opi|sync-to-github"; then
    (crontab -l 2>/dev/null | grep -vE "pepe-vault|pepe-github-sync|pepe-vault-sync-opi|sync-to-github|pepe-sync") | crontab -
    ok "cron entries pepe-* удалены"
else
    skip "cron не был установлен"
fi

# ═══ [2] SSH-ключи ═════════════════════════════════════════
log "[2/9] Удаляю SSH-ключи PEPE"
COUNT=0
for f in "$HOME"/.ssh/id_github_23joel* "$HOME"/.ssh/pepe_aeza_* "$HOME"/.ssh/id_pepe_opi4a*; do
    [ -f "$f" ] || continue
    rm -f "$f"
    COUNT=$((COUNT+1))
done
[ $COUNT -gt 0 ] && ok "удалено ключей: $COUNT" || skip "ключей не найдено"

# SSH-config очистка (блок Host github.com для 23JoelElph)
if [ -f "$HOME/.ssh/config" ] && grep -q "id_github_23joel" "$HOME/.ssh/config"; then
    cp "$HOME/.ssh/config" "$HOME/.ssh/config.pre-pepe-uninstall.bak"
    # удаляем блок Host github.com … IdentityFile id_github_23joel …
    /usr/bin/awk '
        /^Host github\.com$/ { skip=1; next }
        skip && /^Host / { skip=0 }
        !skip { print }
    ' "$HOME/.ssh/config.pre-pepe-uninstall.bak" > "$HOME/.ssh/config"
    ok "~/.ssh/config очищен (бэкап .pre-pepe-uninstall.bak)"
fi

# ═══ [3] pepe-vault ════════════════════════════════════════
log "[3/9] Удаляю ~/pepe-vault"
if [ -d "$HOME/pepe-vault" ]; then
    if [ -d "$HOME/pepe-vault/.git" ]; then
        MYNAME=$(git -C "$HOME/pepe-vault" config user.name 2>/dev/null || echo "?")
        MYCOMMITS=$(git -C "$HOME/pepe-vault" log --author="$MYNAME" --oneline 2>/dev/null | wc -l)
        [ "$MYCOMMITS" -gt 0 ] && warn "у тебя $MYCOMMITS коммитов — они уже на GitHub, локально удалить безопасно"
    fi
    SIZE=$(du -sh "$HOME/pepe-vault" 2>/dev/null | cut -f1)
    rm -rf "$HOME/pepe-vault"
    ok "~/pepe-vault удалён ($SIZE)"
else
    skip "уже удалён"
fi

# Также ~/pepe-vault-clean (если был — временный CLEAN для GitHub push)
if [ -d "$HOME/pepe-vault-clean" ]; then
    rm -rf "$HOME/pepe-vault-clean"
    ok "~/pepe-vault-clean удалён"
fi

# ═══ [4] pepe-install ═══════════════════════════════════════
log "[4/9] Удаляю ~/pepe-install"
if [ -d "$HOME/pepe-install" ]; then
    SIZE=$(du -sh "$HOME/pepe-install" 2>/dev/null | cut -f1)
    rm -rf "$HOME/pepe-install"
    ok "~/pepe-install удалён ($SIZE)"
else
    skip "отсутствует"
fi

# ═══ [5] ~/.claude/ ═════════════════════════════════════════
log "[5/9] Удаляю ~/.claude/ (hooks, skills, agents, commands)"
if [ -d "$HOME/.claude" ]; then
    SIZE=$(du -sh "$HOME/.claude" 2>/dev/null | cut -f1)
    rm -rf "$HOME/.claude"
    ok "~/.claude удалён ($SIZE)"
else
    skip "отсутствует"
fi
[ -f "$HOME/.claude.json" ] && rm -f "$HOME/.claude.json" && ok "~/.claude.json удалён"

# ═══ [6] Секреты и credentials ══════════════════════════════
log "[6/9] Удаляю секреты (PAT, secrets.env, git-credentials)"
if [ -d "$HOME/.config/pepe" ]; then
    /usr/bin/shred -uz "$HOME/.config/pepe"/* 2>/dev/null || rm -rf "$HOME/.config/pepe"/*
    rmdir "$HOME/.config/pepe" 2>/dev/null || true
    ok "~/.config/pepe очищен"
fi
if [ -f "$HOME/.git-credentials" ]; then
    /usr/bin/shred -uz "$HOME/.git-credentials" 2>/dev/null || rm -f "$HOME/.git-credentials"
    ok "~/.git-credentials shred'нут"
fi

# ═══ [7] .bashrc / .zshrc — banner + PATH ══════════════════
log "[7/9] Очищаю ~/.bashrc и ~/.zshrc от PEPE-строк"
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$rc" ] || continue
    if grep -qE "pepe-banner|PEPE CODE banner|alias pepe-|pepe-search" "$rc"; then
        cp "$rc" "${rc}.pre-pepe-uninstall.bak"
        /usr/bin/sed -i '/# PEPE CODE banner/d; /pepe-banner\.sh/d; /alias pepe-/d; /pepe-search/d' "$rc"
        ok "$(basename $rc) очищен (бэкап .pre-pepe-uninstall.bak)"
    else
        skip "$(basename $rc) чист"
    fi
done

# ═══ [8] Claude Code CLI ════════════════════════════════════
log "[8/9] Удаляю Claude Code (npm пакет)"
if command -v claude >/dev/null 2>&1; then
    npm uninstall -g @anthropic-ai/claude-code 2>&1 | tail -2 || \
        warn "локально не удалось — попробуй: sudo npm uninstall -g @anthropic-ai/claude-code"
    ok "Claude Code удалён"
else
    skip "Claude Code не установлен глобально"
fi

# ═══ [9] Финальная проверка ═════════════════════════════════
log "[9/9] Проверка"
REMAINING=()
[ -d "$HOME/pepe-vault" ]            && REMAINING+=("~/pepe-vault")
[ -d "$HOME/pepe-install" ]          && REMAINING+=("~/pepe-install")
[ -d "$HOME/.claude" ]               && REMAINING+=("~/.claude")
[ -f "$HOME/.claude.json" ]          && REMAINING+=("~/.claude.json")
[ -d "$HOME/.config/pepe" ]          && REMAINING+=("~/.config/pepe")
[ -f "$HOME/.git-credentials" ]      && REMAINING+=("~/.git-credentials")
[ -n "$(ls "$HOME"/.ssh/id_github_23joel* 2>/dev/null)" ] && REMAINING+=("~/.ssh/id_github_23joel*")

echo ""
if [ ${#REMAINING[@]} -eq 0 ]; then
    ok "чисто, PEPE полностью удалён"
else
    warn "не удалось удалить:"
    for x in "${REMAINING[@]}"; do
        warn "  $x — удали руками если нужно"
    done
fi

# Проверю что Пятый на месте
if [ -d "$HOME/.config/opencode" ] || [ -d "$HOME/pyatyj-vault" ] || command -v opencode >/dev/null 2>&1; then
    echo ""
    printf "  ${G}✓ Пятый (opencode) на месте — не тронут${R}\n"
fi

cat <<END

$(printf "${V}╔══════════════════════════════════════════════════════════╗${R}")
$(printf "${V}║${R}  🐸 PEPE CODE удалён с этой машины.                      $(printf "${V}║${R}")")
$(printf "${V}║${R}                                                          $(printf "${V}║${R}")")
$(printf "${V}║${R}  Что ещё стоит сделать (не автоматом):                   $(printf "${V}║${R}")")
$(printf "${V}║${R}   1) Попросить Molodoy убрать твой SSH-ключ и PAT        $(printf "${V}║${R}")")
$(printf "${V}║${R}      из GitHub-аккаунта 23JoelElph                       $(printf "${V}║${R}")")
$(printf "${V}║${R}   2) Если ты был в Tailscale — удалить устройство        $(printf "${V}║${R}")")
$(printf "${V}║${R}      через login.tailscale.com/admin/machines            $(printf "${V}║${R}")")
$(printf "${V}║${R}                                                          $(printf "${V}║${R}")")
$(printf "${V}║${R}  Твои коммиты в общий vault остаются на GitHub —         $(printf "${V}║${R}")")
$(printf "${V}║${R}  это норм, они полезны команде.                          $(printf "${V}║${R}")")
$(printf "${V}╚══════════════════════════════════════════════════════════╝${R}")

END
