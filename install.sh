#!/bin/sh
set -eu

REPO_URL="${REPO_URL:-https://github.com/defernest/omniroute-config.git}"
INSTALL_DIR="${INSTALL_DIR:-/opt/omniroute-config}"
OMNIROUTE_PROFILE="${OMNIROUTE_PROFILE:-cli}"

echo "=========================================="
echo " OmniRoute Installer & Deployment Setup"
echo "=========================================="

# Helper function to check command existence
has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# Ensure root privileges for system package installation if needed
sudo_cmd=""
if [ "$(id -u)" -ne 0 ]; then
  if has_cmd sudo; then
    sudo_cmd="sudo"
  else
    echo "Ошибка: требуется доступ root или sudo для установки зависимостей." >&2
    exit 1
  fi
fi

# 1. Install prerequisites if missing
echo "[1/4] Проверка зависимостей (curl, git, docker, docker compose)..."

if ! has_cmd curl; then
  echo "Установка curl..."
  if has_cmd apt-get; then
    $sudo_cmd apt-get update -qq && $sudo_cmd apt-get install -y -qq curl
  elif has_cmd dnf; then
    $sudo_cmd dnf install -y curl
  elif has_cmd yum; then
    $sudo_cmd yum install -y curl
  fi
fi

if ! has_cmd git; then
  echo "Установка git..."
  if has_cmd apt-get; then
    $sudo_cmd apt-get update -qq && $sudo_cmd apt-get install -y -qq git
  elif has_cmd dnf; then
    $sudo_cmd dnf install -y git
  elif has_cmd yum; then
    $sudo_cmd yum install -y git
  fi
fi

if ! has_cmd docker; then
  echo "Docker не найден. Установка Docker через get.docker.com..."
  curl -fsSL https://get.docker.com | $sudo_cmd sh
  if has_cmd systemctl; then
    $sudo_cmd systemctl enable --now docker
  fi
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "Установка плагина docker-compose-plugin..."
  if has_cmd apt-get; then
    $sudo_cmd apt-get update -qq && $sudo_cmd apt-get install -y -qq docker-compose-plugin
  elif has_cmd dnf; then
    $sudo_cmd dnf install -y docker-compose-plugin
  elif has_cmd yum; then
    $sudo_cmd yum install -y docker-compose-plugin
  else
    echo "Не удалось автоматически установить docker compose plugin. Установите его вручную." >&2
    exit 1
  fi
fi

# 2. Setup project files
echo "[2/4] Подготовка файлов конфигурации..."

if [ -f "deploy.sh" ] && [ -f "Caddyfile.template" ] && [ -f "docker-compose.yml" ]; then
  echo "Используется текущий каталог ($(pwd))"
  TARGET_DIR="$(pwd)"
else
  echo "Клонирование конфигурации в $INSTALL_DIR..."
  $sudo_cmd mkdir -p "$INSTALL_DIR"
  $sudo_cmd chown "$(id -u):$(id -g)" "$INSTALL_DIR"
  if [ -d "$INSTALL_DIR/.git" ]; then
    (cd "$INSTALL_DIR" && git pull)
  else
    git clone "$REPO_URL" "$INSTALL_DIR"
  fi
  TARGET_DIR="$INSTALL_DIR"
fi

cd "$TARGET_DIR"

# 3. Make scripts executable
echo "[3/4] Настройка прав на исполнение..."
chmod +x deploy.sh

# 4. Execute deployment
echo "[4/4] Запуск deploy.sh..."
export OMNIROUTE_PROFILE
./deploy.sh
