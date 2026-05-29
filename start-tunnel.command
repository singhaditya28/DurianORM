#!/bin/bash
set -e

CHATWOOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$CHATWOOT_DIR"

echo "================================================"
echo "  Durian ORM — tunnel dev launcher"
echo "================================================"

# ── 1. Install cloudflared if missing ──────────────
if ! command -v cloudflared &>/dev/null; then
  echo ""
  echo "→ cloudflared not found, downloading..."
  ARCH=$(uname -m)
  if [ "$ARCH" = "arm64" ]; then
    CF_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-arm64"
  else
    CF_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-amd64"
  fi
  curl -L "$CF_URL" -o /usr/local/bin/cloudflared
  chmod +x /usr/local/bin/cloudflared
  echo "→ cloudflared installed ✓"
fi

# ── 2. Clear old tunnel log ────────────────────────
rm -f .cloudflared.log

# ── 3. Stop any running Overmind session ───────────
if [ -S ".overmind.sock" ]; then
  echo "→ Stopping existing Overmind session..."
  overmind kill 2>/dev/null || true
  sleep 2
  rm -f .overmind.sock 2>/dev/null || true
fi

# ── 4. Start the full stack ────────────────────────
echo ""
echo "→ Starting Rails + Sidekiq + Vite + Cloudflare tunnel via pnpm tunnel..."
echo "   (watch the output below — the tunnel URL will appear in the 'tunnel' pane)"
echo ""

pnpm tunnel
