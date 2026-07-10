#!/usr/bin/env bash
# PreToolUse blocking gateguard.
# Читает JSON с tool_input, решает:
# - block: явно опасные операции (rm -rf /, dd of=/dev/sd*, chmod 777 / без крайней нужды, force push main)
# - warn: критичные файлы (/etc/, /opt/, /var/www/, sudo, chown/chmod вне ~) — добавляет reminder в контекст
# - pass: обычные операции (тихо)
#
# Правило: не мешаю обычной работе, но заставляю тормозить перед опасным.
set -e
INPUT=$(cat)

python3 - <<PYEOF
import json, sys, re

try:
    data = json.loads('''$INPUT''')
except Exception:
    # если не смогли распарсить — пропускаем (не мешаем)
    print("{}")
    sys.exit(0)

tool = data.get("tool_name", "")
inp = data.get("tool_input", {}) or {}

def block(reason):
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason
        }
    }, ensure_ascii=False))
    sys.exit(0)

def warn(msg):
    """Не блокирует, но добавляет reminder в system-message так,
    чтобы модель видела предупреждение перед исполнением."""
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "ask" if False else "allow",
            "permissionDecisionReason": msg
        }
    }, ensure_ascii=False))
    sys.exit(0)

# ── Bash ──
if tool == "Bash":
    cmd = str(inp.get("command", ""))

    # Абсолютно опасное — блокируем без вопросов.
    # Исключение: /tmp/pepe-allow-mmcblk-write разрешает dd на /dev/mmcblk0
    # (для миграции на OrangePi). sd/nvme/vd/mmcblk1+ всё равно блок.
    import os
    allow_mmcblk0 = os.path.exists("/tmp/pepe-allow-mmcblk-write")
    DANGEROUS = [
        r"\brm\s+-rf?\s+/(?!tmp|var/tmp|var/log/pepe|home/maior/pepe-vault/knowledge-cicada)",  # rm -rf / (кроме tmp/pepe-логов)
        r"\bdd\s+.*of=/dev/(sd|nvme|vd)[a-z]",              # dd на sd/nvme/vd — всегда блок
        r"\bdd\s+.*of=/dev/mmcblk[1-9]",                    # dd на mmcblk1+ — всегда блок
        r"\bmkfs\.\w+\s+/dev/(sd|nvme|mmcblk|vd)[a-z]",   # mkfs на диск
        r"\bchmod\s+-R\s+777\s+/",                        # chmod 777 корня
        r"git\s+push\s+.*--force.*(main|master)",         # force push на main
        r">\s*/dev/sda",                                   # запись на диск
        r"\bshutdown\b|\breboot\b|\bhalt\b|\bpoweroff\b", # выключение
        r":\s*\(\)\s*\{.*:.*\|.*:.*\};\s*:",              # fork bomb
    ]
    for pat in DANGEROUS:
        if re.search(pat, cmd, re.IGNORECASE):
            block(f"❌ БЛОК: команда попадает под опасный паттерн: {pat}\\nПересобери команду или подтверди явно.")

    # mmcblk0 — блок только если нет маркера-разрешения
    if not allow_mmcblk0 and re.search(r"\bdd\s+.*of=/dev/mmcblk0(\s|$)", cmd, re.IGNORECASE):
        block("❌ БЛОК: dd на /dev/mmcblk0 без маркера /tmp/pepe-allow-mmcblk-write.\\nСоздай маркер явно перед dd и удали сразу после.")

    # Sensitive — warn
    SENSITIVE = [
        (r"\bsed\s+-i\b.*(/etc/|/opt/|/var/www/)", "sed -i на sensitive-файл: сначала cp \\$FILE \\$FILE.bak, потом правь. Проверь diff после."),
        (r"\bnginx\s+-s\s+stop", "nginx -s stop оставит сайт мёртвым — если хотел reload, используй systemctl reload nginx"),
        (r"\bsystemctl\s+(stop|disable)\s+(nginx|pepe-admin|fail2ban|ollama)", "Останавливаешь критичный сервис. Точно?"),
        (r"\bcurl\s+.*-o\s+/etc/", "curl -o в /etc/ — реально скачиваешь конфиг из сети в prod? Проверь URL."),
    ]
    for pat, msg in SENSITIVE:
        if re.search(pat, cmd, re.IGNORECASE):
            warn(f"⚠ SENSITIVE: {msg}")
            break

# ── Edit/Write/MultiEdit ──
if tool in ("Edit", "Write", "MultiEdit"):
    path = str(inp.get("file_path", ""))
    CRITICAL_PATHS = ["/etc/", "/opt/", "/var/www/", "/usr/local/", "/usr/bin/", "/boot/"]
    for prefix in CRITICAL_PATHS:
        if path.startswith(prefix):
            warn(f"⚠ CRITICAL PATH: {path} — это prod-файл. Перед правкой: (1) есть ли backup? (2) проверил ли ты кто ссылается через grep -r? (3) точная ли строка old_string?")
            break

# ── всё остальное — пропускаем ──
print("{}")
PYEOF
