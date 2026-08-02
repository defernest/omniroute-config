# omniroute-config

Конфигурация продакшен-развёртывания OmniRoute через Docker Compose (с поддержкой официальных профилей `--profile cli`, `--profile web`, `--profile base`) + Caddy reverse proxy + Redis.

> [!WARNING]
> Выставлять OmniRoute в Интернет (даже с хорошим паролем и за Caddy) — довольно плохая практика!
> _Как временная (и переходная) практика — терпимо. Но не стоит размещать на сервере с какими-либо важными данными или используя внутри персональные ключи._

---

## 🚀 Установка в одну команду (curl | bash)

Для быстрой установки и развёртывания на чистом удалённом сервере Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/defernest/omniroute-config/main/install.sh | bash
```

Скрипт `install.sh`:
- Проверяет и при необходимости автоматически устанавливает зависимости (`curl`, `git`, `docker`, `docker compose`);
- Клонирует конфигурацию в `/opt/omniroute-config` (или использует текущий каталог);
- Автоматически определяет внешний IP сервера;
- Генерирует и валидирует `Caddyfile`;
- Запускает контейнеры OmniRoute с выбранным профилем (`--profile cli` по умолчанию).

---

## 🛠️ Ручной запуск через deploy.sh

Если репозиторий уже склонирован на сервере:

```bash
./deploy.sh
```

Что делает `deploy.sh`:
- Определяет внешний IP сервера (или запрашивает его при необходимости);
- Генерирует `Caddyfile` из шаблона `Caddyfile.template`;
- Валидирует конфиг Caddy в контейнере;
- Запускает `docker compose --profile "$OMNIROUTE_PROFILE" up -d`.

### Настройка профиля и IP через переменные

Выбор профиля (`cli`, `web` или `base`):
```bash
OMNIROUTE_PROFILE=web ./deploy.sh
```

Передача внешнего IP вручную (неинтерактивный режим):
```bash
PUBLIC_SERVER_IP=1.2.3.4 ./deploy.sh
```

Проверка конфигурации без запуска сервисов (Dry Run):
```bash
DRY_RUN=1 ./deploy.sh
```

---

## 🧩 Профили Docker Compose

В развёртывании используются официальные профили OmniRoute:

| Профиль | Образ | Назначение |
| :--- | :--- | :--- |
| **`cli`** _(по умолчанию)_ | `diegosouzapw/omniroute:cli` | Агентские сценарии и встроенные CLI-инструменты (Claude Code, Codex, OpenClaw и др.) |
| **`web`** | `diegosouzapw/omniroute:web` | Провайдеры с web-cookie (Gemini Web, Claude Web) с предустановленным Chromium/Playwright |
| **`base`** | `diegosouzapw/omniroute:latest` | Минимальный headless-сервер без дополнительного окружения |

Пример ручного запуска через `docker compose`:

```bash
# Запуск с CLI-профилем
docker compose --profile cli up -d

# Запуск с WEB-профилем
docker compose --profile web up -d
```

---

## 🌐 Порты

- `80` — HTTP (ACME challenge для Let's Encrypt)
- `443` — HTTPS
- `20130` — HTTPS прокси на Панель управления OmniRoute Dashboard (`omniroute-prod:20128`)
- `20131` — HTTPS прокси на OmniRoute API (`omniroute-prod:20129`)

## 💾 Хранение данных

- `omniroute-prod-data` — хранилище данных приложения (`/app/data`)
- `redis-data` — данные Redis (rate limiter backend & cache)
- `caddy_data`, `caddy_config` — сертификаты и конфигурация Caddy TLS
