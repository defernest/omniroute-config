#!/bin/sh
set -eu

QODER_BASE_URL="https://download.qoder.com/qodercli"
QODER_BINARY_NAME="qodercli"
TMP_DIR=""
APT_UPDATED=0

cleanup() {
  if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR"
  fi
}

die() {
  echo "Error: $1" >&2
  exit 1
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    die "$1 is required"
  fi
}

apt_update_once() {
  if [ "$APT_UPDATED" -eq 0 ]; then
    apt-get update
    APT_UPDATED=1
  fi
}

install_packages() {
  apt_update_once
  apt-get install -y --no-install-recommends "$@"
  rm -rf /var/lib/apt/lists/*
  APT_UPDATED=0
}

download() {
  url="$1"
  output="$2"
  attempt=0

  while [ "$attempt" -lt 3 ]; do
    if [ "$attempt" -gt 0 ]; then
      sleep 2
    fi

    if curl -fsSL --proto '=https' --tlsv1.2 --retry 2 --connect-timeout 30 --max-time 300 "$url" -o "$output"; then
      return 0
    fi

    rm -f "$output" 2>/dev/null || true
    attempt=$((attempt + 1))
  done

  return 1
}

if [ "$(id -u)" -ne 0 ]; then
  die "This script must run as root"
fi

if [ ! -f /etc/os-release ]; then
  die "Cannot detect distribution"
fi

OS_ID="$(. /etc/os-release && printf '%s' "$ID")"
case "$OS_ID" in
  debian|ubuntu) ;;
  *) die "Unsupported distribution: $OS_ID (required: debian/ubuntu)" ;;
esac

require_command apt-get
require_command dpkg

ARCH="$(dpkg --print-architecture)"
case "$ARCH" in
  amd64)
    QODER_ARCH="amd64"
    KILO_ARCHIVE_NAME="kilo-linux-x64.tar.gz"
    ;;
  arm64)
    QODER_ARCH="arm64"
    KILO_ARCHIVE_NAME="kilo-linux-arm64.tar.gz"
    ;;
  *)
    die "Unsupported architecture: $ARCH (required: amd64/arm64)"
    ;;
esac

install_packages curl ca-certificates tar jq
require_command sha256sum

TMP_DIR="$(mktemp -d)"
trap cleanup EXIT INT TERM

manifest="$TMP_DIR/manifest.json"
download "$QODER_BASE_URL/channels/manifest.json" "$manifest" || die "Failed to download qoder manifest"

qoder_url="$(jq -r --arg arch "$QODER_ARCH" '[.. | objects | select(.os? == "linux" and .arch? == $arch and .url?)][0].url // empty' "$manifest")"
qoder_sha256="$(jq -r --arg arch "$QODER_ARCH" '[.. | objects | select(.os? == "linux" and .arch? == $arch and .sha256?)][0].sha256 // empty' "$manifest")"

if [ -z "$qoder_url" ]; then
  die "No qoder release found for linux/$QODER_ARCH"
fi

case "$qoder_url" in
  https://*) ;;
  *) die "Insecure qoder URL: $qoder_url" ;;
esac

qoder_archive="$TMP_DIR/$(basename "$qoder_url")"
download "$qoder_url" "$qoder_archive" || die "Failed to download qoder binary archive"

if [ -n "$qoder_sha256" ]; then
  qoder_actual_sha256="$(sha256sum "$qoder_archive" | cut -d ' ' -f1)"
  if [ "$qoder_actual_sha256" != "$qoder_sha256" ]; then
    die "qoder checksum mismatch"
  fi
fi

qoder_extract_dir="$TMP_DIR/qoder-extract"
mkdir -p "$qoder_extract_dir"

case "$qoder_archive" in
  *.tar.gz|*.tgz)
    tar -xzf "$qoder_archive" -C "$qoder_extract_dir"
    ;;
  *.zip)
    install_packages unzip
    unzip -q "$qoder_archive" -d "$qoder_extract_dir"
    ;;
  *) die "Unsupported qoder archive format: $(basename "$qoder_archive")" ;;
esac

qoder_bootstrap="$qoder_extract_dir/$QODER_BINARY_NAME"
if [ ! -f "$qoder_bootstrap" ]; then
  qoder_bootstrap="$(find "$qoder_extract_dir" -type f -name "$QODER_BINARY_NAME" | head -n 1)"
fi

if [ -z "$qoder_bootstrap" ] || [ ! -f "$qoder_bootstrap" ]; then
  die "qoder binary not found in archive"
fi

chmod +x "$qoder_bootstrap"
"$qoder_bootstrap" install --force --quiet

qoder_installed=""
if command -v qodercli >/dev/null 2>&1; then
  qoder_installed="$(command -v qodercli)"
elif [ -x /root/.local/bin/qodercli ]; then
  qoder_installed="/root/.local/bin/qodercli"
else
  for candidate in /root/.qoder/bin/qodercli/qodercli-*; do
    if [ -f "$candidate" ]; then
      qoder_installed="$candidate"
      break
    fi
  done
fi

if [ -z "$qoder_installed" ]; then
  die "qoder binary not found after installation"
fi

mkdir -p /opt/cli-bin
install -m 0755 "$qoder_installed" /opt/cli-bin/qodercli

kilo_archive_name="$KILO_ARCHIVE_NAME"
kilo_url="https://github.com/Kilo-Org/kilocode/releases/latest/download/${kilo_archive_name}"

kilo_archive="$TMP_DIR/kilo.tar.gz"
download "$kilo_url" "$kilo_archive" || die "Failed to download kilo release archive"

kilo_extract_dir="$TMP_DIR/kilo-extract"
mkdir -p "$kilo_extract_dir"
tar -xzf "$kilo_archive" -C "$kilo_extract_dir"

if [ ! -f "$kilo_extract_dir/kilo" ]; then
  die "kilo binary not found in release archive"
fi

install -m 0755 "$kilo_extract_dir/kilo" /opt/cli-bin/kilo
