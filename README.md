# 🐸 PEPE CODE

Персональный harness Claude Code от Molodoy.

## Что ставится

- **Claude Code CLI** (Anthropic) — базовая AI-IDE.
- **65 навыков** — реверс, разведка, безопасность, разработка (весь ECC пакет + Anthropic Cybersecurity Skills).
- **38 slash-команд** — /tdd, /code-review, /save-memory, /process-inbox, /security и т.д.
- **25 агентов-специалистов** — architect, security-reviewer, python-reviewer и др.
- **10 хуков** — SessionStart, PreToolUse, PostToolUse, Stop (skill-suggester, session-dump, vault-sync).
- **PepeCode banner** — фиолетовое приветствие при старте терминала.
- **Statusline** — своё оформление в Claude Code.

## Установка

Быстро:

```bash
curl -fsSL https://raw.githubusercontent.com/23JoelElph/pepe-install/main/pepe-install.sh | bash -s -- <твоё-имя>
```

Локально (после клонирования):

```bash
git clone https://github.com/23JoelElph/pepe-install.git ~/pepe-install
bash ~/pepe-install/pepe-install.sh <твоё-имя>
```

## Vault (память)

Приватный репо `23JoelElph/pepe-vault`. Молодой добавляет тебя как collaborator — тогда:

```bash
# получи PAT (Personal Access Token, scope: repo) — от Molodoy
git clone https://<PAT>@github.com/23JoelElph/pepe-vault.git ~/pepe-vault
```

Автосинк раз в 8 часов (09:00 / 15:00 / 22:00) на домашний сервер OPi через Tailscale.

## После установки

- Открой новый терминал → увидишь `PEPECODE 🐸` фиолетовым.
- Запусти `claude` — Claude Code стартует с PEPE-хуками, статуслайном, всеми навыками.

## Обновление

```bash
cd ~/pepe-install && git pull && bash pepe-install.sh <твоё-имя>
```

Скрипт идемпотентный — можно запускать N раз.

## Автор

Molodoy — [[user-molodoy]] · вдохновлён [[friends-formica]] и системой Пятый.
