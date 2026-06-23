#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────
# Home Hub — One-click Installer for macOS
# ──────────────────────────────────────────────
# Usage: bash scripts/install.sh
# What it does:
#   1. Install system dependencies (Homebrew, ffmpeg, python, pyatv)
#   2. Install Docker Desktop (via brew cask)
#   3. Deploy Home Assistant via docker-compose
#   4. Clone & configure home-hub
#   5. Guide you through HA init + token generation
# ──────────────────────────────────────────────

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HA_DIR="$HOME/homeassistant"
HA_PORT="${HA_PORT:-8123}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
err()  { echo -e "${RED}✗${NC} $1"; }

# ── 1. System Dependencies ────────────────────

echo ""
echo "═══════════════════════════════════════"
echo " Step 1/5 — System Dependencies"
echo "═══════════════════════════════════════"

if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  log "Homebrew already installed"
fi

brew install ffmpeg python@3.12 2>/dev/null || brew upgrade ffmpeg python@3.12

if ! python3 -c "import pyatv" 2>/dev/null; then
  pip3 install pyatv
  log "pyatv installed"
else
  log "pyatv already installed"
fi

# ── 2. Docker ─────────────────────────────────

echo ""
echo "═══════════════════════════════════════"
echo " Step 2/5 — Docker Desktop"
echo "═══════════════════════════════════════"

if ! command -v docker &>/dev/null; then
  echo "Installing Docker Desktop (this opens a GUI installer)..."
  brew install --cask docker
  warn "Open Docker.app manually to complete setup, then wait for the whale icon in menu bar."
  echo "  Press Enter after Docker is running..."
  read -r
else
  log "Docker already installed"
fi

if ! docker info &>/dev/null; then
  err "Docker daemon not running. Open Docker.app and try again."
  exit 1
fi
log "Docker daemon is running"

# ── 3. Home Assistant ─────────────────────────

echo ""
echo "═══════════════════════════════════════"
echo " Step 3/5 — Home Assistant (Docker)"
echo "═══════════════════════════════════════"

mkdir -p "$HA_DIR/config"
cd "$HA_DIR"

if [ ! -f docker-compose.yml ]; then
  cat > docker-compose.yml <<EOF
version: '3.8'
services:
  homeassistant:
    image: homeassistant/home-assistant:stable
    container_name: homeassistant
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./config:/config
      - /etc/localtime:/etc/localtime:ro
    environment:
      - TZ=Asia/Shanghai
EOF
  log "docker-compose.yml created"
else
  log "docker-compose.yml already exists"
fi

if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^homeassistant$'; then
  echo "Starting Home Assistant..."
  docker compose up -d
  echo "Waiting for HA to boot (this may take 2-3 min)..."
  for i in $(seq 1 30); do
    if curl -s "http://127.0.0.1:${HA_PORT}/" >/dev/null 2>&1; then
      log "Home Assistant is running at http://localhost:${HA_PORT}"
      break
    fi
    sleep 6
  done
  if ! curl -s "http://127.0.0.1:${HA_PORT}/" >/dev/null 2>&1; then
    warn "HA didn't respond in 3 min. Check: docker compose logs -f"
  fi
else
  log "Home Assistant container already running"
fi

cd "$REPO_DIR"

# ── 4. Init HA (manual) ──────────────────────

echo ""
echo "═══════════════════════════════════════"
echo " Step 4/5 — Initialize Home Assistant"
echo "═══════════════════════════════════════"
echo ""
echo "  Open http://localhost:${HA_PORT} in your browser and:"
echo "    1. Create an admin account"
echo "    2. Set your home location"
echo "    3. Name your home"
echo ""
echo "  Then generate a Long-Lived Token:"
echo "    HA Web UI → bottom-left user → Security"
echo "    → Long-Lived Access Tokens → Create Token"
echo ""
read -r -p "  Have you completed the above? Paste your HA token here (or press Enter to skip): " HA_TOKEN

if [ -n "$HA_TOKEN" ]; then
  cd "$REPO_DIR"
  if [ ! -f .env ]; then
    cp .env.example .env
  fi

  # Update .env with user's input
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|HASS_URL=.*|HASS_URL=http://localhost:${HA_PORT}|" .env 2>/dev/null || true
    sed -i '' "s|HASS_TOKEN=.*|HASS_TOKEN=${HA_TOKEN}|" .env 2>/dev/null || true
  else
    sed -i "s|HASS_URL=.*|HASS_URL=http://localhost:${HA_PORT}|" .env 2>/dev/null || true
    sed -i "s|HASS_TOKEN=.*|HASS_TOKEN=${HA_TOKEN}|" .env 2>/dev/null || true
  fi
  log ".env configured"
fi

# ── 5. Verify ─────────────────────────────────

echo ""
echo "═══════════════════════════════════════"
echo " Step 5/5 — Verify"
echo "═══════════════════════════════════════"

echo ""
echo "  Run: bash scripts/hub-ctl status"
echo ""
echo "  Discover AirPlay devices:"
echo "    bash scripts/hub-ctl airplay scan"
echo "    Then edit ROOMS array in scripts/hub-ctl"
echo ""
echo "  Optional — enable Hermes Agent integration:"
echo "    ln -sf \"\$(pwd)/SKILL.md\" ~/.hermes/skills/home-hub/SKILL.md"
echo "    hermes tools enable homeassistant"
echo ""

log "Installation complete!"
echo ""
