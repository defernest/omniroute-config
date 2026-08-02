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

## 🔒 Настройка TLS и Сохранение Сертификатов

Сертификаты и данные Caddy сохраняются на диске хоста в папке `./caddy_data`, поэтому при перезапусках контейнеров **повторный запрос к ACME / Let's Encrypt не происходит** — используется ранее сохранённый сертификат.

Выбор режима TLS задаётся через переменную `TLS_MODE`:

| Режим `TLS_MODE` | Описание |
| :--- | :--- |
| **`acme`** _(по умолчанию)_ | Автоматический сертификат Let's Encrypt для IP. Сохраняется в `./caddy_data` на диске. |
| **`internal`** | Внутренний CA Caddy (`tls internal`) — без внешних вызовов к ACME, без лимитов и требований к 80/443 порту. |
| **`custom`** | Использование собственных сертификатов из `./caddy_data/certs/cert.crt` и `key.key`. |

Примеры запуска:

```bash
# Использовать внутренние сертификаты Caddy (без вызова ACME):
TLS_MODE=internal ./deploy.sh

# Использовать ACME Let's Encrypt с сохранением в ./caddy_data:
TLS_MODE=acme ./deploy.sh
```

---

## 🛠️ Ручной запуск через deploy.sh

Если репозиторий уже склонирован на сервере:

```bash
./deploy.sh
```

### Дополнительные переменные окружения

```bash
# Выбор профиля OmniRoute (cli, web, base)
OMNIROUTE_PROFILE=web ./deploy.sh

# Передача внешнего IP вручную (неинтерактивный режим)
PUBLIC_SERVER_IP=1.2.3.4 ./deploy.sh

# Проверка конфигурации без запуска (Dry Run)
DRY_RUN=1 ./deploy.sh
```

---

## 🧩 Профили Docker Compose

| Профиль | Образ | Назначение |
| :--- | :--- | :--- |
| **`cli`** _(по умолчанию)_ | `diegosouzapw/omniroute:latest` | Агентские сценарии и встроенные CLI-инструменты |
| **`web`** | `diegosouzapw/omniroute:web` | Провайдеры с web-cookie (Gemini Web, Claude Web) с Chromium |
| **`base`** | `diegosouzapw/omniroute:latest` | Минимальный headless-сервер |

---

## 🌐 Порты и Файловая Система

- `80` — HTTP (ACME challenge для Let's Encrypt)
- `443` — HTTPS
- `20130` — HTTPS прокси на Панель управления OmniRoute Dashboard (`omniroute-prod:20128`)
- `20131` — HTTPS прокси на OmniRoute API (`omniroute-prod:20129`)

### Данные

- `./caddy_data` — персистентное хранилище сертификатов Caddy на хосте
- `./caddy_config` — конфигурация Caddy на хосте
- `omniroute-prod-data` — данные OmniRoute (`/app/data`)
- `redis-data` — данные Redis (rate limiter & cache)
