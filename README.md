# omniroute-config

Минимальный конфиг прод-развертывания Omniroute через Docker Compose + Caddy.

## Запуск

```bash
docker compose up -d
```

## Что внутри

- `omniroute-prod` — приложение Omniroute (`diegosouzapw/omniroute:3.6.6`)
- `caddy` — reverse proxy и TLS termination

## Порты

- `80` — HTTP (ACME challenge)
- `443` — HTTPS
- `20130` — прокси на `omniroute-prod:20128`
- `20131` — прокси на `omniroute-prod:20129`

## Данные

- `omniroute-prod-data` — данные приложения (`/app/data`)
- `caddy_data`, `caddy_config` — состояние Caddy/TLS
