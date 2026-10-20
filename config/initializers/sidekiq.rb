# config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.redis = {
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"),
    ssl_params: {verify_mode: OpenSSL::SSL::VERIFY_NONE}
  }

  # Ya no hay jobs recurrentes: borra el cron de inventario que pudo quedar guardado en Redis.
  config.on(:startup) { Sidekiq::Cron::Job.destroy_all! if defined?(Sidekiq::Cron::Job) }
end

Sidekiq.configure_client do |config|
  config.redis = {
    url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"),
    ssl_params: {verify_mode: OpenSSL::SSL::VERIFY_NONE}
  }
end
