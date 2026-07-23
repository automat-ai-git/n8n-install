# FORK.md — реестр отличий форка от upstream

Форк: [automat-ai-git/n8n-install](https://github.com/automat-ai-git/n8n-install)
Upstream: [kossakovsky/selfhost-ai](https://github.com/kossakovsky/selfhost-ai) (до июля 2026 — `kossakovsky/n8n-install`)

Назначение файла: при каждом мерже upstream проверять по этому списку, что кастомизации форка не потерялись. Обновлять при добавлении/удалении собственных изменений.

Последняя синхронизация с upstream: **v1.8.0** (2026-07-23).

## Отличия в отслеживаемых файлах

### docker-compose.yml

| # | Что | Зачем |
|---|-----|-------|
| 1 | `WEBHOOK_URL: "${N8N_WEBHOOK_URL:-...}"` — override через `N8N_WEBHOOK_URL` | Вебхуки принимаются на отдельном домене |
| 2 | Модели авто-загрузки Ollama: `qwen2.5:0.5b`, `bge-m3` (вместо `qwen2.5:7b-instruct-q4_K_M`, `nomic-embed-text`) | Свой набор моделей под задачи и железо |
| 3 | `start_period: 60s` в healthcheck n8n (вместо 30s) | Медленный старт n8n |
| 4 | `QDRANT__SERVICE__JWT_RBAC: "${QDRANT_MULTITENANCY}"` у qdrant | Мультитенантность Qdrant (JWT RBAC) |
| 5 | У caddy добавлены env: `CADDY_TRUSTED_PROXIES`, `SEARXNG_TRUSTED_IPS` | Параметризация доверенных сетей (см. Caddyfile) |

> **Убрано в v1.8.0:** ручной GPU-пиннинг Ollama (`device_ids: ['${OLLAMA_GPU_DEVICE:-0}']`) — заменён на нативный механизм upstream (`OLLAMA_GPU_COUNT` / `OLLAMA_GPU_DEVICES`). Переменная `OLLAMA_GPU_DEVICE` из `.env.example` удалена.

### Caddyfile / caddy-addon

- `Caddyfile`: у SearXNG матчер `@protected not remote_ip {$SEARXNG_TRUSTED_IPS:...}` — доверенные подсети обходят basic auth; значения задаются в рабочем `.env`
- `caddy-addon/global.conf` (только в форке): `trusted_proxies static {$CADDY_TRUSTED_PROXIES:private_ranges}` + `ocsp_stapling off`; импортируется в глобальный блок Caddyfile

### .env.example

- `SCARF_ANALYTICS=false` — телеметрия выключена (раскомментировано)
- `N8N_WEBHOOK_URL=` — отдельный вебхук-домен (см. правку №1 compose)
- `GENERIC_TIMEZONE="Europe/Moscow"`, `TZ="Europe/Moscow"`
- `SEARXNG_TRUSTED_IPS`, `CADDY_TRUSTED_PROXIES` — generic-дефолты; реальные значения только в рабочем `.env` (в репо не хранятся)
- `GOST_NO_PROXY` — не забывать добавлять новые сервисы upstream; реальный суженный список подсетей — только в рабочем `.env`
- `QDRANT_MULTITENANCY=true`
- `POSTIZ_DISABLE_REGISTRATION=true`

### docker-compose.override.yml.example (машинно-специфичный слой WSL2)

Живые кастомизации (рабочие):
- `comfyui` — кастомный образ `yanwk/comfyui-boot`, GPU-пиннинг `device_ids: ['1']` (**upstream comfyui GPU не покрывает — держим ручной**), тома моделей
- `invokeai-nvidia` — тома моделей (шаринг с ComfyUI read-only через `/comfyui-models`, выход в `storage-user/output/invokeai`)
- `postgres` — тонкий healthcheck-тайминг (start_period 20s, retries 12) под медленный старт postiz (**НЕ обход бага — не удалять**)
- `ollama-gpu` — свои `OLLAMA_*` env (context 131072, keep-alive 5h и т.д.), внешние модели `/mnt/d/models`
- WSL2-фиксы: `node-exporter`/`cadvisor` (иначе load average >900), `clickhouse` disable_syslogs
- `mem_limit: 16g` для docling; `*meeting-data` тома у многих сервисов; `prometheus` retention

Закомментировано в v1.8.0 (пробуем нативный механизм upstream, откат — раскомментировать):
- GPU-пиннинг `ollama-gpu` / `ollama-pull-llama-gpu` / `invokeai-nvidia` через `CUDA_VISIBLE_DEVICES` — заменяем на `OLLAMA_GPU_DEVICES` / `INVOKEAI_GPU_DEVICES` в `.env`. **WSL2 caveat: device_ids не изолирует карты** — если не сработает, раскомментировать CUDA/NVIDIA.

Убрано в v1.8.0 (покрыто сборкой):
- healthcheck-обходы `gotenberg`, `uptime-kuma`, `databasus`, `appsmith`, `comfyui`, `paddleocr`, `lightrag` — upstream #85 починил их штатно (у paddleocr/lightrag оставлен только `start_period` под медленный старт)
- `ragflow` nginx.conf-mount — upstream #86 отдал nginx образу (стоковый лимит загрузки 1024M вместо 100M)

### Файлы только форка (upstream их не имеет / не трогает)

- `docker-compose.override.yml.example` — пример пользовательских override'ов
- `caddy-addon/global.conf` — глобальные настройки Caddy (см. выше)
- `disable_syslogs.xml` — отключение syslog (WSL2)
- `paddlex/ocr_config.yml` — расширенная конфигурация PaddleOCR
- `storage/`, `storage-models/`, `storage-user/` — структура каталогов под модели и данные (`.gitkeep`)
- `docling/tessdata/` — данные tesseract для docling

### Удалено в форке

- `.claude/` целиком исключён из репо (в `.gitignore`). При мерже удалять всё, что upstream добавляет в `.claude/` (было: `commands/add-new-service.md`; в v1.8.0: `skills/fix-issues/SKILL.md`)
- `ragflow/nginx.conf` — удалён при мерже v1.8.0 (upstream убрал использование)

### README.md

- Свой URL клонирования (`automat-ai-git/n8n-install`) + описание форка

## Процедура мержа upstream

1. `git fetch upstream`
2. Репетиция: `git merge-tree --write-tree main upstream/main` — посмотреть конфликты заранее
3. `git merge upstream/main` — конфликты обычно в: `docker-compose.yml` (правки №1–5), `.env.example` (`GOST_NO_PROXY`)
4. Убрать всё новое в `.claude/` (`git rm --cached`), проверить override.example на обходы, покрытые сборкой
5. Проверка: `docker compose config --quiet` с override, `bash -n` по скриптам
6. Обновить этот файл (версия синхронизации, новые отличия)

## Развёртывание

Рабочий `.env` живёт только на сервере (git его не трогает). После обновления проверить, что в нём заданы реальные значения `SEARXNG_TRUSTED_IPS`, `CADDY_TRUSTED_PROXIES`, `GOST_NO_PROXY`. Рабочий `docker-compose.override.yml` на сервере правится руками синхронно с `.example` (он gitignored).

## История

- **v1.8.0** (2026-07-23): удалён Hermes (upstream #88 — не настраивали, потери нет); нативный GPU-пиннинг вместо ручного; чистка healthcheck-обходов и ragflow nginx.
- **v1.7.1** (2026-07-12): первый большой мерж после переименования проекта; добавлены InvokeAI, вынос секретов из публичного репо.
