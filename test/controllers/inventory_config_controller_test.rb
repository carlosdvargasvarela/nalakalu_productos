# test/controllers/inventory_config_controller_test.rb
require "test_helper"

class InventoryConfigControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:admin)
  end

  test "update_exit_prefixes guarda la lista global de prefijos de salida" do
    patch inventory_sync_config_exit_prefixes_url, params: { exit_order_prefixes: "PED-4, PED-5" }

    assert_redirected_to inventory_sync_config_path
    assert_equal ["PED-4", "PED-5"], InventorySyncConfig.current.exit_order_prefixes_array
  end

  test "test_classify detecta salida por palabra clave de producto cuando matchea un prefijo de salida" do
    InventorySyncConfig.current.update!(exit_order_prefixes: ["PED-4"])
    showrooms(:escazu).update!(product_keywords: ["VENDIDO SALA SE"])

    post inventory_sync_config_test_classify_url, params: {
      order_number: "PED-4-00123",
      product_name: "Sofá VENDIDO SALA SE"
    }

    json = JSON.parse(@response.body)
    assert json["matched"]
    assert_equal "exit", json["movements"].first["type"]
    assert_equal showrooms(:escazu).name, json["movements"].first["showroom"]
  end

  test "test_classify reporta sala ambigua sin romper cuando matchean varias salas" do
    InventorySyncConfig.current.update!(exit_order_prefixes: ["PED-4"])
    showrooms(:escazu).update!(product_keywords: ["VENDIDO"])
    showrooms(:guanacaste).update!(product_keywords: ["VENDIDO"])

    post inventory_sync_config_test_classify_url, params: {
      order_number: "PED-4-00123",
      product_name: "Sofá VENDIDO"
    }

    json = JSON.parse(@response.body)
    assert json["matched"]
    assert_match "Ambigua", json["movements"].first["showroom"]
  end
end
