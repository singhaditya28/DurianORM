class GlobalConfigService
  def self.load(config_key, default_value)
    config = GlobalConfig.get(config_key)[config_key]
    return config if config.present?

    # To support migrating existing instance relying on env variables
    # TODO: deprecate this later down the line
    config_value = ENV.fetch(config_key) { default_value }

    return if config_value.blank?

    i = InstallationConfig.where(name: config_key).first_or_initialize
    # If the record already exists but has a blank value (e.g. was seeded before the ENV was
    # populated), update it so the real ENV value takes effect without needing a DB wipe.
    if i.new_record? || i.value.blank?
      i.value = config_value
      i.locked = false
      i.save!
    end
    # To clear a nil value that might have been cached in the previous call
    GlobalConfig.clear_cache
    i.value
  end

  def self.account_signup_enabled?
    load('ENABLE_ACCOUNT_SIGNUP', 'false').to_s != 'false'
  end
end
