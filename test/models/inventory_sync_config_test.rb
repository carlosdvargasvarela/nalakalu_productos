require "test_helper"
require "minitest/mock"

class InventorySyncConfigTest < ActiveSupport::TestCase
  test "exit_order_prefixes_array normaliza y descarta valores vacíos" do
    config = InventorySyncConfig.current
    config.update!(exit_order_prefixes: ["PED-4", " PED-5 ", ""])

    assert_equal ["PED-4", "PED-5"], config.reload.exit_order_prefixes_array
  end

  test "exit_order_prefixes_array es vacío por defecto" do
    assert_equal [], InventorySyncConfig.current.exit_order_prefixes_array
  end

  test "apply_schedule! registra el cron job con args como Array, no Hash" do
    config = InventorySyncConfig.current
    config.update!(schedule_enabled: true, schedule_cron: "0 6 * * *")

    captured = nil
    stub = ->(hash) { captured = hash }

    Sidekiq::Cron::Job.stub :create, stub do
      config.apply_schedule!
    end

    # Un Hash acá produce `perform_later({})` (1 arg posicional) en vez de
    # `perform_later()` — y SyncInventoryJob#perform solo acepta keyword args,
    # así que con Hash el job revienta con ArgumentError en cada corrida.
    assert_equal [], captured[:args]
    assert_kind_of Array, captured[:args]
    assert_equal "SyncInventoryJob", captured[:class]
    assert_equal "0 6 * * *", captured[:cron]
  end

  test "apply_schedule! destruye el cron job cuando el schedule está deshabilitado" do
    config = InventorySyncConfig.current
    config.update!(schedule_enabled: false)

    destroyed_name = nil
    stub = ->(name) { destroyed_name = name }

    Sidekiq::Cron::Job.stub :destroy, stub do
      config.apply_schedule!
    end

    assert_equal "Auto Sync Inventario", destroyed_name
  end
end
