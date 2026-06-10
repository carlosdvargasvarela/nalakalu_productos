# config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.redis = {
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"),
    ssl_params: {verify_mode: OpenSSL::SSL::VERIFY_NONE}
  }

  if defined?(Sidekiq::Cron::Job)
    config.on(:startup) do
      config = InventorySyncConfig.current
      config.apply_schedule! if config.schedule_enabled?
    end
  end
end

Sidekiq.configure_client do |config|
  config.redis = {
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"),
    ssl_params: {verify_mode: OpenSSL::SSL::VERIFY_NONE}
  }
end
