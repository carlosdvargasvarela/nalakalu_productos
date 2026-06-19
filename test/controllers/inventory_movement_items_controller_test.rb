# test/controllers/inventory_movement_items_controller_test.rb
require "test_helper"

class InventoryMovementItemsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:admin)
    @sync    = InventorySync.create!(from_date: Date.current, to_date: Date.current, status: "pending_review")
    @product = products(:one)
  end

  test "asigna producto y resuelve un movimiento que ya tenía sala" do
    movement = InventoryMovement.create!(
      inventory_sync: @sync, movement_type: "exit", source: "synced", status: "unresolved",
      quantity: 1, order_number: "PED-4-001", showroom: showrooms(:palmares), product_name_raw: "Sofá"
    )

    patch inventory_movement_url(movement), params: { inventory_movement: { product_id: @product.id } }

    movement.reload
    assert_redirected_to inventory_sync_path(@sync)
    assert_equal "resolved", movement.status
    assert_equal @product.id, movement.product_id
    assert_equal showrooms(:palmares).id, movement.showroom_id
  end

  test "no resuelve un movimiento ambiguo si no se indica la sala" do
    movement = InventoryMovement.create!(
      inventory_sync: @sync, movement_type: "exit", source: "synced", status: "unresolved",
      quantity: 1, order_number: "PED-4-002", showroom: nil, product_name_raw: "Sofá VENDIDO"
    )

    patch inventory_movement_url(movement), params: { inventory_movement: { product_id: @product.id } }

    movement.reload
    assert_redirected_to inventory_sync_path(@sync)
    assert_equal "unresolved", movement.status
    assert_nil movement.showroom_id
  end

  test "resuelve un movimiento ambiguo cuando se selecciona producto y sala juntos" do
    movement = InventoryMovement.create!(
      inventory_sync: @sync, movement_type: "exit", source: "synced", status: "unresolved",
      quantity: 1, order_number: "PED-4-003", showroom: nil, product_name_raw: "Sofá VENDIDO"
    )

    patch inventory_movement_url(movement), params: {
      inventory_movement: { product_id: @product.id, showroom_id: showrooms(:escazu).id }
    }

    movement.reload
    assert_equal "resolved", movement.status
    assert_equal showrooms(:escazu).id, movement.showroom_id
  end

  test "ignore marca el movimiento como ignorado sin requerir producto ni sala" do
    movement = InventoryMovement.create!(
      inventory_sync: @sync, movement_type: "exit", source: "synced", status: "unresolved",
      quantity: 1, order_number: "PED-4-004", showroom: nil, product_name_raw: "Sofá VENDIDO"
    )

    patch inventory_movement_url(movement), params: { ignore: true }

    assert_equal "ignored", movement.reload.status
  end
end
