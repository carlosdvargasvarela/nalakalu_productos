require "test_helper"

class InventorySyncConfigTest < ActiveSupport::TestCase
  test "exit_order_prefixes_array normaliza y descarta valores vacíos" do
    config = InventorySyncConfig.current
    config.update!(exit_order_prefixes: ["PED-4", " PED-5 ", ""])

    assert_equal ["PED-4", "PED-5"], config.reload.exit_order_prefixes_array
  end

  test "exit_order_prefixes_array es vacío por defecto" do
    assert_equal [], InventorySyncConfig.current.exit_order_prefixes_array
  end
end
