#!/bin/bash
cd "$(dirname "$0")"

echo "================================================"
echo "  Chatwoot — restart Rails + Sidekiq only"
echo "  (tunnel is NOT restarted — URL stays the same)"
echo "================================================"
echo ""

# Show the current tunnel URL before restarting
TUNNEL_URL=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' .cloudflared.log 2>/dev/null | tail -1)
if [ -n "$TUNNEL_URL" ]; then
  echo "  Current tunnel URL: $TUNNEL_URL"
  echo ""
  # Keep .env in sync with the running tunnel URL
  sed -i '' "s|^FRONTEND_URL=.*|FRONTEND_URL=$TUNNEL_URL|" .env
  echo "  ✓ .env FRONTEND_URL confirmed: $TUNNEL_URL"
else
  echo "  ⚠ Could not read tunnel URL from .cloudflared.log"
  echo "    Check that the tunnel is running (pnpm tunnel)"
fi

echo ""
echo "→ Restarting Rails..."
overmind restart backend
echo "  ✓ Rails restarted"

echo "→ Restarting Sidekiq..."
overmind restart worker
echo "  ✓ Sidekiq restarted"

echo ""
echo "✓ Done. Open: ${TUNNEL_URL:-<tunnel URL>}/app"
echo "[Safe to close this window]"
