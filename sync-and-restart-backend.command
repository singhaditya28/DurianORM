#!/bin/bash
cd "$(dirname "$0")"

echo "→ Syncing FRONTEND_URL into DB..."
bundle exec rails chatwoot:sync_env_configs

echo ""
echo "✓ Done. Your tunnel URL is:"
echo "  https://missouri-contents-hospitals-dean.trycloudflare.com"
echo ""
echo "Paste that into Meta Developer Portal for all webhook / OAuth / App Domain fields."
echo "[Process will exit — safe to close this window]"
