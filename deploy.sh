#!/bin/sh
set -eu

TEMPLATE_FILE="Caddyfile.template"
GENERATED_FILE="Caddyfile"
PLACEHOLDER="<public_server_ip>"

if ! command -v docker >/dev/null 2>&1; then
  echo "Ошибка: нужен docker" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "Ошибка: нужен curl" >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "Ошибка: нужен плагин docker compose" >&2
  exit 1
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "Ошибка: не найден шаблон $TEMPLATE_FILE" >&2
  exit 1
fi

if ! grep -q "$PLACEHOLDER" "$TEMPLATE_FILE"; then
  echo "Ошибка: в $TEMPLATE_FILE нет плейсхолдера $PLACEHOLDER" >&2
  exit 1
fi

is_valid_ipv4() {
  ip="$1"
  printf '%s' "$ip" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$' || return 1
  old_ifs="$IFS"
  IFS='.'
  set -- $ip
  IFS="$old_ifs"
  for octet in "$@"; do
    if [ "$octet" -gt 255 ] 2>/dev/null; then
      return 1
    fi
  done
  return 0
}

detect_public_ip() {
  for endpoint in "https://api.ipify.org" "https://ifconfig.me/ip" "https://icanhazip.com"; do
    detected="$(curl -fsSL --connect-timeout 5 --max-time 10 "$endpoint" 2>/dev/null | tr -d '[:space:]' || true)"
    if [ -n "$detected" ] && is_valid_ipv4 "$detected"; then
      printf '%s' "$detected"
      return 0
    fi
  done
  return 1
}

SERVER_IP="${PUBLIC_SERVER_IP:-}"

if [ -z "$SERVER_IP" ]; then
  DETECTED_IP="$(detect_public_ip || true)"

  if [ -n "$DETECTED_IP" ]; then
    printf 'Найден внешний IP: %s. Использовать его? [Y/n]: ' "$DETECTED_IP"
    read -r answer
    case "$answer" in
      ""|y|Y|yes|YES|д|Д|да|ДА)
        SERVER_IP="$DETECTED_IP"
        ;;
      *)
        printf 'Введите корректный внешний IP: '
        read -r SERVER_IP
        ;;
    esac
  else
    printf 'Не удалось определить внешний IP автоматически. Введите внешний IP: '
    read -r SERVER_IP
  fi
fi

if ! is_valid_ipv4 "$SERVER_IP"; then
  echo "Ошибка: некорректный IPv4: $SERVER_IP" >&2
  exit 1
fi

sed "s|$PLACEHOLDER|$SERVER_IP|g" "$TEMPLATE_FILE" > "$GENERATED_FILE"

docker run --rm -v "$(pwd)/$GENERATED_FILE:/etc/caddy/Caddyfile:ro" caddy:2.11-alpine caddy validate --config /etc/caddy/Caddyfile >/dev/null

if [ "${DRY_RUN:-0}" = "1" ]; then
  echo "Готово: $GENERATED_FILE создан и валиден"
  exit 0
fi

docker compose up -d --build
