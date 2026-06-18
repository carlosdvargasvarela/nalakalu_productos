# test/controllers/inventory_movements_controller_test.rb
require "test_helper"

class InventoryMovementsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:admin)
    @showroom = showrooms(:palmares)
    @product  = products(:one)
  end

  test "should get index con movimientos manuales (renderiza toolbar de bulk actions y modales)" do
    InventoryMovement.create!(
      movement_type: "exit", source: "manual", status: "resolved",
      product: @product, showroom: @showroom, quantity: 1, delivery_date: Date.current
    )

    get inventory_movements_log_url

    assert_response :success
    assert_select "#bulkReassignShowroomModal"
    assert_select "#bulkEditNoteModal"
    assert_select "input[type=checkbox][data-bulk-check-target=checkbox]", 1
  end

  test "bulk_destroy preserva los filtros activos al redirigir al log" do
    movement = InventoryMovement.create!(
      movement_type: "exit", source: "manual", status: "resolved",
      product: @product, showroom: @showroom, quantity: 1, delivery_date: Date.current
    )

    delete bulk_destroy_inventory_movements_url, params: {
      ids: [movement.id],
      showroom_id: @showroom.id,
      product_id: @product.id,
      movement_type: "exit",
      from: "2026-01-01",
      to: "2026-12-31"
    }

    assert_redirected_to inventory_movements_log_path(
      showroom_id: @showroom.id.to_s,
      product_id: @product.id.to_s,
      movement_type: "exit",
      from: "2026-01-01",
      to: "2026-12-31"
    )
  end

  test "bulk_export descarga un xlsx de los movimientos seleccionados" do
    movement = InventoryMovement.create!(
      movement_type: "exit", source: "manual", status: "resolved",
      product: @product, showroom: @showroom, quantity: 1, delivery_date: Date.current
    )

    get bulk_export_inventory_movements_url, params: { ids: [movement.id] }

    assert_response :success
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", @response.media_type
  end

  test "bulk_export sin selección redirige con alerta" do
    get bulk_export_inventory_movements_url, params: { ids: [] }
    assert_redirected_to inventory_movements_log_path
    assert_equal "No seleccionaste ningún movimiento.", flash[:alert]
  end

  test "bulk_reassign_showroom reasigna solo movimientos manuales y preserva filtros" do
    other_showroom = showrooms(:escazu)
    manual = InventoryMovement.create!(
      movement_type: "exit", source: "manual", status: "resolved",
      product: @product, showroom: @showroom, quantity: 1, delivery_date: Date.current
    )
    synced = InventoryMovement.create!(
      movement_type: "exit", source: "synced", status: "resolved",
      product: @product, showroom: @showroom, quantity: 1, delivery_date: Date.current
    )

    patch bulk_reassign_showroom_inventory_movements_url, params: {
      ids: [manual.id, synced.id],
      new_showroom_id: other_showroom.id,
      showroom_id: @showroom.id,
      movement_type: "exit"
    }

    assert_equal other_showroom.id, manual.reload.showroom_id
    assert_equal @showroom.id, synced.reload.showroom_id, "los movimientos sincronizados no deben reasignarse"
    assert_redirected_to inventory_movements_log_path(showroom_id: @showroom.id.to_s, movement_type: "exit")
  end

  test "bulk_edit_note reemplaza solo los campos enviados y deja intactos los vacíos" do
    manual = InventoryMovement.create!(
      movement_type: "exit", source: "manual", status: "resolved",
      product: @product, showroom: @showroom, quantity: 1, delivery_date: Date.current,
      order_number: "ORIGINAL-PEDIDO", notes: "Nota original"
    )

    patch bulk_edit_note_inventory_movements_url, params: {
      ids: [manual.id],
      note: "Nota nueva",
      order_number: ""
    }

    manual.reload
    assert_equal "Nota nueva", manual.notes
    assert_equal "ORIGINAL-PEDIDO", manual.order_number, "el campo vacío no debe sobrescribir el valor existente"
  end

  test "bulk_edit_note no afecta movimientos sincronizados" do
    synced = InventoryMovement.create!(
      movement_type: "exit", source: "synced", status: "resolved",
      product: @product, showroom: @showroom, quantity: 1, delivery_date: Date.current,
      notes: "Nota original"
    )

    patch bulk_edit_note_inventory_movements_url, params: { ids: [synced.id], note: "Intento de edición" }

    assert_equal "Nota original", synced.reload.notes
  end
end
