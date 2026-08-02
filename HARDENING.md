# OmniRoute Deployment Hardening Guide

Этот документ описывает комплексные меры по обеспечению безопасности (Hardening) при развёртывании OmniRoute на удалённом сервере.

---

## 🛡️ 1. Безопасность приложения OmniRoute (Уровень контейнера)

### 1.1 Переменные окружения шифрования и безопасности
Добавьте в файл `.env` (или секцию `environment` сервиса OmniRoute в `docker-compose.yml`):

```env
# Ключ шифрования данных на диске (AES-256-GCM) для API-ключей и токенов в SQLite
STORAGE_ENCRYPTION_KEY=сгенерируйте_случайный_64_символьный_hex_ключ

# Защита auth-cookie поверх HTTPS
AUTH_COOKIE_SECURE=true

# Секретный ключ для подписи JWT-токенов сессий
JWT_SECRET=сгенерируйте_случайный_длинный_секретный_ключ
```

_Сгенерировать случайный ключ можно командой: `openssl rand -hex 32`_

---

## 🔒 2. Защита обратного прокси Caddy

### 2.1 HTTP Basic Auth для панели управления (Dashboard)
Чтобы закрыть доступ к панели управления `https://<ip>:20130` на уровне Caddy до прохождения авторизации самого OmniRoute:

1. Сгенерируйте хэш пароля командой:
   ```bash
   docker run --rm caddy:2.11-alpine caddy hash-password --plaintext "ВашПароль"
   ```
2. Включите `basic_auth` в `Caddyfile.template`:
   ```caddy
   <public_server_ip>:20130 {
       basic_auth {
           admin $2a$14$хэш_вашего_пароля
       }
       reverse_proxy omniroute-prod:20128
       ...
   }
   ```

### 2.2 Ограничение доступа по IP (IP Whitelisting)
Если вы подключаетесь к Панели управления или API только с фиксированных IP-адресов:

```caddy
<public_server_ip>:20130 {
    @allowed_ips {
        remote_ip 1.2.3.4 5.6.7.8
    }
    handle @allowed_ips {
        reverse_proxy omniroute-prod:20128
    }
    handle {
        respond "Access Denied" 403
    }
}
```

### 2.3 Усиленные Заголовки Безопасности (Security Headers)
В секции `header` Caddyfile:

```caddy
header {
    Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    X-Frame-Options "DENY"
    X-Content-Type-Options "nosniff"
    X-XSS-Protection "1; mode=block"
    Referrer-Policy "strict-origin-when-cross-origin"
    Permissions-Policy "camera=(), microphone=(), geolocation=(), payment=(), usb=(), serial=()"
    -Server
}
```

---

## 🐳 3. Изоляция контейнеров и лимиты ресурсов (Docker Hardening)

### 3.1 Ограничение прав контейнеров (Capability Drop & Security Opts)
В `docker-compose.yml`:

```yaml
services:
  caddy:
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
    mem_limit: 150m
    pids_limit: 100

  redis:
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    mem_limit: 100m
    pids_limit: 50

  omniroute-cli:
    security_opt:
      - no-new-privileges:true
    mem_limit: 512m
    pids_limit: 200
```

### 3.2 Сетевая изоляция
Убедитесь, что `omniroute-prod` и `redis` **не имеют публичных портов** в `ports:` (только `expose:`), а доступны исключительно во внутренней сети `internal_network`.

---

## 🌐 4. Защита на уровне хоста и сети (VPS / Linux OS)

### 4.1 Межсетевой экран (UFW / Firewall)
Разрешите только необходимые порты на сервере:

```bash
# Блокировка всех входящих подключений по умолчанию
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Разрешить SSH
sudo ufw allow 22/tcp

# Разрешить HTTP/HTTPS для Caddy
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 20130/tcp
sudo ufw allow 20131/tcp

# Включить UFW
sudo ufw enable
```

### 4.2 Перенос управления в VPN / Tailscale / SSH-туннель (Наиболее безопасный вариант)
Самый надежный способ обезопасить OmniRoute — **не выставлять порт 20130 в интернет**:

- **Сценарий 1: SSH Туннелирование**:
  Закройте порт 20130 наружу и подключайтесь к панели с вашего компьютера:
  ```bash
  ssh -L 20130:127.0.0.1:20130 root@87.199.203.51
  ```
  И открывайте панель в браузере по адресу `https://localhost:20130`.

- **Сценарий 2: Tailscale / WireGuard**:
  Настройте Tailscale на VPS и привяжите Caddy к внутреннему IP-адресу Tailscale (`100.x.y.z`).
