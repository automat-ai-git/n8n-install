# FORK.md — реестр отличий форка от upstream

Форк: [automat-ai-git/n8n-install](https://github.com/automat-ai-git/n8n-install)
Upstream: [kossakovsky/selfhost-ai](https://github.com/kossakovsky/selfhost-ai) (до июля 2026 — `kossakovsky/n8n-install`)

Назначение файла: при каждом мерже upstream проверять по этому списку, что кастомизации форка не потерялись. Обновлять при добавлении/удалении собственных изменений.

Последняя синхронизация с upstream: **v1.7.1** (2026-07-12).

## Отличия в отслеживаемых файлах

### docker-compose.yml (5 правок)

| # | Что | Зачем |
|---|-----|-------|
| 1 | `WEBHOOK_URL: "${N8N_WEBHOOK_URL:-...}"` — override через `N8N_WEBHOOK_URL` | Вебхуки Telegram идут через отдельный домен/сервер (цепочка прокси), а не через `N8N_HOSTNAME` |
| 2 | Модели авто-загрузки Ollama: `qwen2.5:0.5b`, `bge-m3` (вместо `qwen2.5:7b-instruct-q4_K_M`, `nomic-embed-text`) | Свой набор моделей под задачи и железо |
| 3 | `start_period: 60s` в healthcheck n8n (вместо 30s) | Медленный старт n8n на домашнем сервере |
| 4 | `QDRANT__SERVICE__JWT_RBAC: "${QDRANT_MULTITENANCY}"` у qdrant | Мультитенантность Qdrant (JWT RBAC) |
| 5 | Ollama GPU: `device_ids: ['${OLLAMA_GPU_DEVICE:-0}']` вместо `count: 1` | Выбор конкретной GPU на многокарточной машине |

### .env.example

- `SCARF_ANALYTICS=false` — телеметрия выключена (раскомментировано)
- `N8N_WEBHOOK_URL=` — отдельный вебхук-домен (см. правку №1 compose)
- `GENERIC_TIMEZONE="Europe/Moscow"`, `TZ="Europe/Moscow"`
- `GOST_NO_PROXY` — вместо широкого `10.0.0.0/8` точечные подсети `10.9.9.0/27, 10.8.1.0/27, 10.8.8.0/27` (+ поясняющие комментарии); не забывать добавлять новые сервисы upstream (последние добавленные: `hermes`, `invokeai`)
- `OLLAMA_GPU_DEVICE=1` — индекс GPU для Ollama
- `QDRANT_MULTITENANCY=true`
- `POSTIZ_DISABLE_REGISTRATION=true`

### Файлы только форка (upstream их не имеет / не трогает)

- `docker-compose.override.yml.example` — пример пользовательских override'ов (в т.ч. `mem_limit` для docling)
- `caddy-addon/global.conf` — свои глобальные настройки Caddy
- `disable_syslogs.xml` — отключение syslog (WSL2)
- `paddlex/ocr_config.yml` — расширенная конфигурация PaddleOCR
- `storage/`, `storage-models/`, `storage-user/` — структура каталогов под модели и данные (`.gitkeep`)
- `docling/tessdata/` — данные tesseract для docling

### Удалено в форке

- `.claude/commands/add-new-service.md` — каталог `.claude` исключён из репо (в `.gitignore`); при мерже конфликт modify/delete решать как «оставить удалённым»

### README.md

- Свой URL клонирования (`automat-ai-git/n8n-install`) + ~16 строк описания форка

## Процедура мержа upstream

1. `git fetch upstream`
2. Репетиция: `git merge-tree --write-tree main upstream/main` — посмотреть конфликты заранее
3. `git merge upstream/main` — конфликты обычно в: `docker-compose.yml` (кавычки vs правки №1–5), `.env.example` (`GOST_NO_PROXY`), `README.md`, `add-new-service.md` (оставить удалённым)
4. Проверка: все 5 правок compose на месте, `docker compose config --quiet`, `bash -n` по скриптам
5. Обновить этот файл (версия синхронизации, новые отличия)

## Внешняя инфраструктура (вне репо)

Рабочий `.env`, кастомные сервисы и nginx-цепочка (Голландия → Россия → домашний сервер) живут на серверах, не в этом репозитории. Новые hostname сервисов требуют правок nginx на VDS (`server_name` + `certbot --expand`).
