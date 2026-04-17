# omniroute-config

Минимальный конфиг прод-развёртывания Omniroute через Docker Compose + Caddy.

> [!WARNING]
> Выставлять OmniRoute в Интернет (даже с хорошим паролем и за Caddy) - довольно плохая практика!

_Как временная (и переходная) практика - терпимо. Но не стоит размещать на сервере с какими-либо важными данными или используя внутри персональные ключи._

## Быстрый запуск

`Caddyfile.template` в репозитории — это шаблон с плейсхолдером `<public_server_ip>`.

```bash
./deploy.sh
```

Что делает скрипт:

- определяет внешний IP сервера;
- спрашивает подтверждение (или просит ввести IP вручную);
- генерирует `Caddyfile`;
- валидирует конфиг Caddy в контейнере;
- запускает `docker compose up -d --build`.

Для неинтерактивного запуска можно передать IP через переменную:

```bash
PUBLIC_SERVER_IP=1.2.3.4 ./deploy.sh
```

Проверка без запуска сервисов:

```bash
DRY_RUN=1 ./deploy.sh
```

## Ручной запуск

```bash
docker compose up -d --build
```

## Что внутри

- `omniroute-prod` — приложение Omniroute (`diegosouzapw/omniroute:3.6.6`)
- `caddy` — reverse proxy и TLS termination

### CLI and tools

- Qoder AI CLI
- Kilo Code

## Порты

- `80` — HTTP (ACME challenge)
- `443` — HTTPS
- `20130` — прокси на `omniroute-prod:20128`
- `20131` — прокси на `omniroute-prod:20129`

## Данные

- `omniroute-prod-data` — данные приложения (`/app/data`)
- `caddy_data`, `caddy_config` — состояние Caddy/TLS
