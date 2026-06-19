class InventorySyncConfig < ApplicationRecord
  include SerializedArrayAttribute

  array_attribute :exit_order_prefixes

  validates :default_days_back,  numericality: { greater_than_or_equal_to: 0 }
  validates :default_days_forward, numericality: { greater_than_or_equal_to: 0 }
  validates :schedule_days_back, numericality: { greater_than: 0 }

  CRON_PRESETS = {
    "daily_6am"   => "0 6 * * *",
    "daily_midnight" => "0 0 * * *",
    "weekly_monday"  => "0 6 * * 1",
    "hourly"         => "0 * * * *"
  }.freeze

  def self.current
    first_or_create!(
      default_days_back:    7,
      default_days_forward: 0,
      schedule_enabled:     false,
      schedule_cron:        "0 6 * * *",
      schedule_days_back:   14
    )
  end

  def default_from_date
    Date.current - default_days_back.days
  end

  def default_to_date
    Date.current + default_days_forward.days
  end

  def apply_schedule!
    return unless defined?(Sidekiq::Cron::Job)

    job_name = "Auto Sync Inventario"
    if schedule_enabled? && schedule_cron.present?
      # sidekiq-cron envuelve un Hash como UN argumento posicional (`perform_later({})`),
      # pero SyncInventoryJob#perform solo acepta keyword args — eso generaba
      # "wrong number of arguments (given 1, expected 0)" en cada corrida automática.
      # Un Array vacío sí produce `perform_later()`, sin args, dejando que los
      # defaults internos del job (from/to/user_id) se calculen solos.
      Sidekiq::Cron::Job.create(
        name:  job_name,
        cron:  schedule_cron,
        class: "SyncInventoryJob",
        args:  []
      )
    else
      Sidekiq::Cron::Job.destroy(job_name) rescue nil
    end
  end
end
