#!/usr/bin/env bash
set -euo pipefail

: "${SITE_SLUG:?SITE_SLUG is required (e.g. vela-viento)}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> build-one: SITE_SLUG=$SITE_SLUG"

CONTENT_DIR="$ROOT/content"
DATA_DIR="$ROOT/data/projects"
IMAGES_DIR="$ROOT/static/images/projects"
QR_DIR="$ROOT/static/qr"

# Cloudflare Pages обычно выставляет CF_PAGES=1
IS_CF_PAGES="${CF_PAGES:-}"

TMP_DIR=""
if [ -z "$IS_CF_PAGES" ]; then
  # ЛОКАЛЬНО: бэкап + восстановление, чтобы у тебя ничего не “пропало”
  TMP_DIR="$(mktemp -d)"
  echo "==> Local mode: backup to $TMP_DIR"

  cleanup() {
    echo "==> Restoring backups..."
    rm -rf "$CONTENT_DIR" "$DATA_DIR" "$IMAGES_DIR" "$QR_DIR"
    mkdir -p "$ROOT/data" "$ROOT/static"
    mv "$TMP_DIR/content" "$CONTENT_DIR" 2>/dev/null || true
    mv "$TMP_DIR/projects" "$DATA_DIR" 2>/dev/null || true
    mv "$TMP_DIR/images_projects" "$IMAGES_DIR" 2>/dev/null || true
    mv "$TMP_DIR/qr" "$QR_DIR" 2>/dev/null || true
    rm -rf "$TMP_DIR"
  }
  trap cleanup EXIT

  mv "$CONTENT_DIR" "$TMP_DIR/content"
  mv "$DATA_DIR" "$TMP_DIR/projects"
  mv "$IMAGES_DIR" "$TMP_DIR/images_projects"
  mv "$QR_DIR" "$TMP_DIR/qr"

  mkdir -p "$CONTENT_DIR" "$DATA_DIR" "$IMAGES_DIR" "$QR_DIR"

  # --- content/<slug>/ ---
  if [ -d "$TMP_DIR/content/$SITE_SLUG" ]; then
    cp -R "$TMP_DIR/content/$SITE_SLUG" "$CONTENT_DIR/$SITE_SLUG"
  else
    echo "ERROR: content/$SITE_SLUG not found"
    exit 1
  fi

  # --- data/projects/<slug>.json ---
  if [ -f "$TMP_DIR/projects/$SITE_SLUG.json" ]; then
    cp "$TMP_DIR/projects/$SITE_SLUG.json" "$DATA_DIR/$SITE_SLUG.json"
  else
    echo "ERROR: data/projects/$SITE_SLUG.json not found"
    exit 1
  fi

  # --- images/projects/<slug>/ ---
  if [ -d "$TMP_DIR/images_projects/$SITE_SLUG" ]; then
    cp -R "$TMP_DIR/images_projects/$SITE_SLUG" "$IMAGES_DIR/$SITE_SLUG"
  else
    echo "WARN: static/images/projects/$SITE_SLUG not found"
  fi

  # --- qr/<slug>-qr.png (ТОЛЬКО ОДИН) ---
  QR_FILE="$TMP_DIR/qr/${SITE_SLUG}-qr.png"
  if [ -f "$QR_FILE" ]; then
    cp "$QR_FILE" "$QR_DIR/${SITE_SLUG}-qr.png"
  else
    echo "ERROR: QR not found: static/qr/${SITE_SLUG}-qr.png"
    echo "       Check filename in static/qr/ (it must match <slug>-qr.png)"
    exit 1
  fi

else
  # CLOUDFLARE: среда одноразовая, можно резать без бэкапа
  echo "==> Cloudflare mode: shrink workspace for single-site build"

  # В Cloudflare репо уже есть, поэтому можем просто удалить лишнее
  # content: оставить только одну папку
  find content -mindepth 1 -maxdepth 1 -type d ! -name "$SITE_SLUG" -exec rm -rf {} +
  if [ ! -d "content/$SITE_SLUG" ]; then
    echo "ERROR: content/$SITE_SLUG not found"
    exit 1
  fi

  # data/projects: оставить только один json
  find data/projects -type f -name "*.json" ! -name "${SITE_SLUG}.json" -delete
  if [ ! -f "data/projects/${SITE_SLUG}.json" ]; then
    echo "ERROR: data/projects/${SITE_SLUG}.json not found"
    exit 1
  fi

  # images/projects: оставить только одну папку
  if [ -d "static/images/projects" ]; then
    find static/images/projects -mindepth 1 -maxdepth 1 -type d ! -name "$SITE_SLUG" -exec rm -rf {} +
  fi

  # qr: оставить только один файл <slug>-qr.png
  if [ -d "static/qr" ]; then
    find static/qr -type f -name "*.png" ! -name "${SITE_SLUG}-qr.png" -delete
    if [ ! -f "static/qr/${SITE_SLUG}-qr.png" ]; then
      echo "ERROR: static/qr/${SITE_SLUG}-qr.png not found"
      exit 1
    fi
  else
    echo "ERROR: static/qr folder not found"
    exit 1
  fi
fi

echo "==> Running hugo --minify"
hugo --minify

echo "==> Done: built single-site for $SITE_SLUG"
