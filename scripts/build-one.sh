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

# Cloudflare Pages env detection (CF_PAGES is common; CF_PAGES_BRANCH exists too)
IS_CF_PAGES="${CF_PAGES_BRANCH:-${CF_PAGES:-}}"

TMP_DIR=""

############################################
# ========== LOCAL MODE ===================
############################################
if [ -z "$IS_CF_PAGES" ]; then

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

  # Move originals into backup
  mv "$CONTENT_DIR" "$TMP_DIR/content"
  mv "$DATA_DIR" "$TMP_DIR/projects"
  mv "$IMAGES_DIR" "$TMP_DIR/images_projects"
  mv "$QR_DIR" "$TMP_DIR/qr"

  # Re-create empty dirs
  mkdir -p "$CONTENT_DIR" "$DATA_DIR" "$IMAGES_DIR" "$QR_DIR"

  # --- CONTENT: keep only content/<slug>/ ---
  if [ -d "$TMP_DIR/content/$SITE_SLUG" ]; then
    cp -R "$TMP_DIR/content/$SITE_SLUG" "$CONTENT_DIR/$SITE_SLUG"
  else
    echo "ERROR: content/$SITE_SLUG not found"
    exit 1
  fi

  # Make selected project the homepage: content/_index.md => builds /
  if [ -f "$CONTENT_DIR/$SITE_SLUG/index.md" ]; then
    cp "$CONTENT_DIR/$SITE_SLUG/index.md" "$CONTENT_DIR/_index.md"
  else
    echo "ERROR: content/$SITE_SLUG/index.md not found"
    exit 1
  fi

  # --- DATA: keep only data/projects/<slug>.json ---
  if [ -f "$TMP_DIR/projects/$SITE_SLUG.json" ]; then
    cp "$TMP_DIR/projects/$SITE_SLUG.json" "$DATA_DIR/$SITE_SLUG.json"
  else
    echo "ERROR: data/projects/$SITE_SLUG.json not found"
    exit 1
  fi

  # --- IMAGES: keep only static/images/projects/<slug>/ ---
  if [ -d "$TMP_DIR/images_projects/$SITE_SLUG" ]; then
    cp -R "$TMP_DIR/images_projects/$SITE_SLUG" "$IMAGES_DIR/$SITE_SLUG"
  else
    echo "WARN: images not found for $SITE_SLUG (static/images/projects/$SITE_SLUG)"
  fi

  # --- QR: keep only static/qr/<slug>-qr.png ---
  QR_FILE="$TMP_DIR/qr/${SITE_SLUG}-qr.png"
  if [ -f "$QR_FILE" ]; then
    cp "$QR_FILE" "$QR_DIR/${SITE_SLUG}-qr.png"
  else
    echo "ERROR: QR not found: static/qr/${SITE_SLUG}-qr.png"
    exit 1
  fi

############################################
# ========== CLOUDFLARE MODE ==============
############################################
else

  echo "==> Cloudflare mode: shrinking workspace"

  # content: keep only one project folder
  find content -mindepth 1 -maxdepth 1 -type d ! -name "$SITE_SLUG" -exec rm -rf {} +

  if [ ! -d "content/$SITE_SLUG" ]; then
    echo "ERROR: content/$SITE_SLUG not found"
    exit 1
  fi

  # Make selected project the homepage: content/_index.md => builds /
  if [ -f "content/$SITE_SLUG/index.md" ]; then
    cp "content/$SITE_SLUG/index.md" "content/_index.md"
  else
    echo "ERROR: content/$SITE_SLUG/index.md not found"
    exit 1
  fi

  # data: keep only one json
  find data/projects -type f -name "*.json" ! -name "${SITE_SLUG}.json" -delete

  if [ ! -f "data/projects/${SITE_SLUG}.json" ]; then
    echo "ERROR: data/projects/${SITE_SLUG}.json not found"
    exit 1
  fi

  # images: keep only one project folder
  if [ -d "static/images/projects" ]; then
    find static/images/projects -mindepth 1 -maxdepth 1 -type d ! -name "$SITE_SLUG" -exec rm -rf {} +
  fi

  # qr: keep only one file
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

############################################
echo "==> Running hugo --minify"
hugo --minify

echo "==> Done: built single-site for $SITE_SLUG"
