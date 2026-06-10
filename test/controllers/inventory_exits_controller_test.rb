# test/controllers/inventory_exits_controller_test.rb
require "test_helper"
require "minitest/mock"

class InventoryExitsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  class FakeLogisticsClient
    def initialize(deliveries = [])
      @deliveries = deliveries
    end

    def fetch_deliveries(*)
      @deliveries
    end
  end

  setup do
    sign_in users(:admin)
    @showroom = showrooms(:palmares)
    @product  = products(:one)
  end

  test "should get new" do
    get new_inventory_exit_url
    assert_response :success
  end

  test "consultar pedido muestra los datos de la entrega encontrada" do
    delivery = {
      "order_number" => "2-00123",
      "client" => { "name" => "Cliente de Prueba" },
      "delivery_date" => "2026-06-01",
      "items" => [{ "product_name" => "Sofá 3 puestos", "quantity_delivered" => 2 }]
    }

    LogisticsApiClient.stub :new, FakeLogisticsClient.new([delivery]) do
      get new_inventory_exit_url, params: { order_number: "2-00123" }
    end

    assert_response :success
    assert_match "Cliente de Prueba", @response.body
  end

  test "consultar pedido muestra aviso cuando no se encuentra ninguna entrega" do
    LogisticsApiClient.stub :new, FakeLogisticsClient.new([]) do
      get new_inventory_exit_url, params: { order_number: "9-99999" }
    end

    assert_response :success
    assert_match "No se encontró ningún pedido", @response.body
  end

  test "registra múltiples salidas con stock suficiente sin generar alerta" do
    InventoryMovement.create!(movement_type: "initial", source: "manual", status: "resolved",
      product: @product, showroom: @showroom, quantity: 5, delivery_date: Date.current)

    assert_difference("InventoryMovement.count") do
      post inventory_exits_url, params: {
        showroom_id: @showroom.id,
        items: { "0" => { product_id: @product.id, quantity: 2, notes: "Venta a cliente" } }
      }
    end

    movement = InventoryMovement.order(:created_at).last
    assert_equal "exit", movement.movement_type
    assert_equal "manual", movement.source
    assert_equal "resolved", movement.status
    assert_nil movement.flag
    assert_redirected_to inventory_path
  end

  test "registra salida con stock insuficiente y la marca con flag stock_missing" do
    assert_difference("InventoryMovement.count") do
      post inventory_exits_url, params: {
        showroom_id: @showroom.id,
        items: { "0" => { product_id: @product.id, quantity: 3, notes: "Venta a cliente" } }
      }
    end

    movement = InventoryMovement.order(:created_at).last
    assert_equal "stock_missing", movement.flag
    assert_match "Alerta automática", movement.notes
  end

  test "registra múltiples productos en una sola petición" do
    product2 = products(:two)
    InventoryMovement.create!(movement_type: "initial", source: "manual", status: "resolved",
      product: @product, showroom: @showroom, quantity: 10, delivery_date: Date.current)
    InventoryMovement.create!(movement_type: "initial", source: "manual", status: "resolved",
      product: product2, showroom: @showroom, quantity: 10, delivery_date: Date.current)

    assert_difference("InventoryMovement.count", 2) do
      post inventory_exits_url, params: {
        showroom_id: @showroom.id,
        items: {
          "0" => { product_id: @product.id, quantity: 1, notes: "" },
          "1" => { product_id: product2.id, quantity: 2, notes: "" }
        }
      }
    end

    assert_redirected_to inventory_path
  end
end
