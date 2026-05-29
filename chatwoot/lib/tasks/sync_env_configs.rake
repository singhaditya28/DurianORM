# Sync ENV-based config keys into the installation_configs table.
#
# Run after updating .env to make sure the app picks up new values:
#   bundle exec rails chatwoot:sync_env_configs
#
namespace :chatwoot do
  desc 'Force-sync ENV config values into installation_configs DB table and clear cache'
  task sync_env_configs: :environment do
    SOCIAL_CONFIG_KEYS = %w[
      FB_APP_ID
      FB_APP_SECRET
      FB_VERIFY_TOKEN
      INSTAGRAM_APP_ID
      INSTAGRAM_APP_SECRET
      INSTAGRAM_VERIFY_TOKEN
      IG_VERIFY_TOKEN
    ].freeze

    puts "\n== Syncing social channel config keys to DB ==\n"

    SOCIAL_CONFIG_KEYS.each do |key|
      env_val = ENV[key].presence
      record  = InstallationConfig.find_by(name: key)

      if env_val.blank?
        puts "  SKIP  #{key}  (not set in ENV)"
        next
      end

      if record.nil?
        InstallationConfig.create!(name: key, value: env_val, locked: false)
        puts "  CREATE #{key}  => #{env_val[0..6]}..."
      elsif record.value.blank? || record.value != env_val
        record.update!(value: env_val)
        puts "  UPDATE #{key}  => #{env_val[0..6]}..."
      else
        puts "  OK     #{key}  (already up to date)"
      end
    end

    GlobalConfig.clear_cache
    puts "\nCache cleared. Restart your Rails server for changes to take effect.\n"
  end
end
