#!/bin/bash
# Enable channel_instagram feature for all accounts

cd "$(dirname "$0")"

echo "→ Enabling channel_instagram feature for all accounts..."

bundle exec rails runner "
  Account.find_each do |account|
    unless account.feature_enabled?('channel_instagram')
      account.enable_features!('channel_instagram')
      puts \"  Enabled channel_instagram for account: \#{account.name} (ID: \#{account.id})\"
    else
      puts \"  OK  channel_instagram already enabled for account: \#{account.name} (ID: \#{account.id})\"
    end
  end
  puts 'Done.'
"

echo ""
echo "✓ Complete."
echo "[Process will exit — safe to close this window]"
