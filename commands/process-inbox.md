---
description: "Обработать всё что лежит в ~/pepe-vault/inbox/ через ingest pipeline: конвертирует в knowledge/, ищет entities, пишет memory/*.md с wiki-linked фактами. Прими решение stopover — если ingest нашёл что-то важное, я предложу обработать вручную."
---

Обрабатываю всё что в inbox:

```bash
python3 ~/pepe-vault/scripts/ingest/process_inbox.py
```

После — я читаю созданные memory/ingest-*.md, смотрю на найденные entities, и если что-то заслуживает более детального разбора (например ELF-файл с интересными strings, или PDF с новым проектом) — предлагаю следующий шаг (запустить skill `analyzing-linux-elf-malware` или создать полноценную wiki-страницу).

Финальный шаг: если обработалось что-то содержательное (не тестовое), запустить `build_brain.py`, чтобы новые узлы попали в мозг.
