# test/controllers/inventory_alerts_controller_test.rb
require "test_helper"

class InventoryAlertsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:admin)
    @showroom = showrooms(:palmares)
    @product  = products(:one)
    @alert = InventoryMovement.create!(
      movement_type: "exit", source: "manual", status: "resolved",
      product: @product, showroom: @showroom, quantity: 3, delivery_date: Date.current,
      flag: "stock_missing",
      notes: "Alerta automática: se registró una salida de 3 pero el stock calculado era 0."
    )
  end

  test "should get index and list flagged movements" do
    get inventory_alerts_url
    assert_response :success
    assert_match @product.name, @response.body
  end

  test "resuelve una alerta registrando un ajuste de stock initial y limpia el flag dejando trazabilidad" do
    assert_difference("InventoryMovement.count") do
      patch resolve_inventory_alert_url(@alert),
        params: { create_adjustment: "1", adjustment_quantity: "3", note: "Se confirmó conteo físico." }
    end

    @alert.reload
    assert_nil @alert.flag
    assert_match "Resolución", @alert.notes
    assert_match "Se confirmó conteo físico.", @alert.notes

    adjustment = InventoryMovement.order(:created_at).last
    assert_equal "initial", adjustment.movement_type
    assert_equal @product, adjustment.product
    assert_equal @showroom, adjustment.showroom
  end

  test "resuelve una alerta sin crear ajuste cuando no se solicita uno" do
    assert_no_difference("InventoryMovement.count") do
      patch resolve_inventory_alert_url(@alert), params: { note: "Era un error de digitación." }
    end

    @alert.reload
    assert_nil @alert.flag
    assert_match "Era un error de digitación.", @alert.notes
  end
end
