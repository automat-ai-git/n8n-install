# FORK.md — реестр отличий форка от upstream

Форк: [automat-ai-git/n8n-install](https://github.com/automat-ai-git/n8n-install)
Upstream: [kossakovsky/selfhost-ai](https://github.com/kossakovsky/selfhost-ai) (до июля 2026 — `kossakovsky/n8n-install`)

Назначение файла: при каждом мерже upstream проверять по этому списку, что кастомизации форка не потерялись. Обновлять при добавлении/удалении собственных изменений.

Последняя синхронизация с upstream: **v1.7.1** (2026-07-12).

## Отличия в отслеживаемых файлах

### docker-compose.yml

| # | Что | Зачем |
|---|-----|-------|
| 1 | `WEBHOOK_URL: "${N8N_WEBHOOK_URL:-...}"` — override через `N8N_WEBHOOK_URL` | Вебхуки принимаются на отдельном домене |
| 2 | Модели авто-загрузки Ollama: `qwen2.5:0.5b`, `bge-m3` (вместо `qwen2.5:7b-instruct-q4_K_M`, `nomic-embed-text`) | Свой набор моделей под задачи и железо |
| 3 | `start_period: 60s` в healthcheck n8n (вместо 30s) | Медленный старт n8n |
| 4 | `QDRANT__SERVICE__JWT_RBAC: "${QDRANT_MULTITENANCY}"` у qdrant | Мультитенантность Qdrant (JWT RBAC) |
| 5 | Ollama GPU: `device_ids: ['${OLLAMA_GPU_DEVICE:-0}']` вместо `count: 1` | Выбор конкретной GPU на многокарточной машине |
| 6 | У caddy добавлены env: `CADDY_TRUSTED_PROXIES`, `SEARXNG_TRUSTED_IPS` | Параметризация доверенных сетей (см. Caddyfile) |

### Caddyfile / caddy-addon

- `Caddyfile`: у SearXNG матчер `@protected not remote_ip {$SEARXNG_TRUSTED_IPS:...}` — доверенные подсети обходят basic auth; значения задаются в рабочем `.env`
- `caddy-addon/global.conf` (только в форке): `trusted_proxies static {$CADDY_TRUSTED_PROXIES:private_ranges}` + `ocsp_stapling off`; импортируется в глобальный блок Caddyfile

### .env.example

- `SCARF_ANALYTICS=false` — телеметрия выключена (раскомментировано)
- `N8N_WEBHOOK_URL=` — отдельный вебхук-домен (см. правку №1 compose)
- `GENERIC_TIMEZONE="Europe/Moscow"`, `TZ="Europe/Moscow"`
- `SEARXNG_TRUSTED_IPS`, `CADDY_TRUSTED_PROXIES` — generic-дефолты; реальные значения только в рабочем `.env` (в репо не хранятся)
- `GOST_NO_PROXY` — не забывать добавлять новые сервисы upstream (последние добавленные: `hermes`, `invokeai`); реальный суженный список подсетей — только в рабочем `.env`
- `OLLAMA_GPU_DEVICE=1` — индекс GPU для Ollama
- `QDRANT_MULTITENANCY=true`
- `POSTIZ_DISABLE_REGISTRATION=true`

### Файлы только форка (upstream их не имеет / не трогает)

- `docker-compose.override.yml.example` — пример пользовательских override'ов (в т.ч. `mem_limit` для docling)
- `caddy-addon/global.conf` — глобальные настройки Caddy (см. выше)
- `disable_syslogs.xml` — отключение syslog (WSL2)
- `paddlex/ocr_config.yml` — расширенная конфигурация PaddleOCR
- `storage/`, `storage-models/`, `storage-user/` — структура каталогов под модели и данные (`.gitkeep`)
- `docling/tessdata/` — данные tesseract для docling

### Удалено в форке

- `.claude/commands/add-new-service.md` — каталог `.claude` исключён из репо (в `.gitignore`); при мерже конфликт modify/delete решать как «оставить удалённым»

### README.md

- Свой URL клонирования (`automat-ai-git/n8n-install`) + описание форка

## Процедура мержа upstream

1. `git fetch upstream`
2. Репетиция: `git merge-tree --write-tree main upstream/main` — посмотреть конфликты заранее
3. `git merge upstream/main` — конфликты обычно в: `docker-compose.yml` (правки №1–6), `.env.example` (`GOST_NO_PROXY`), `README.md`, `add-new-service.md` (оставить удалённым)
4. Проверка: все правки compose на месте, `docker compose config --quiet`, `bash -n` по скриптам
5. Обновить этот файл (версия синхронизации, новые отличия)

## Развёртывание

Рабочий `.env` живёт только на сервере (git его не трогает). После обновления проверить, что в нём заданы реальные значения `SEARXNG_TRUSTED_IPS`, `CADDY_TRUSTED_PROXIES`, `GOST_NO_PROXY` — иначе применятся широкие generic-дефолты (функционально безопасно, но менее строго).
