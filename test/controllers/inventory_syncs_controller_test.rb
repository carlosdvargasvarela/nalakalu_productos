require "test_helper"

class InventorySyncsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:admin)
  end

  test "sync de tipo logistics_sync muestra el título de sincronización" do
    sync = InventorySync.create!(from_date: Date.current, to_date: Date.current, status: "pending_review")

    get inventory_sync_url(sync)

    assert_response :success
    assert_match "Revisión de sincronización", @response.body
  end

  test "sync de tipo bulk_upload muestra el título de carga masiva y sus import_errors" do
    sync = InventorySync.create!(
      from_date: Date.current, to_date: Date.current, status: "pending_review",
      kind: "bulk_upload", deliveries_processed: 3, movements_count: 2,
      import_errors: ["Fila 4: sala emisora 'X' no encontrada."]
    )

    get inventory_sync_url(sync)

    assert_response :success
    assert_match "Revisión de carga masiva", @response.body
    assert_match "filas procesadas", @response.body
    assert_match "Fila 4: sala emisora", @response.body
  end

  test "show con ítems pendientes renderiza la barra de bulk actions y el modal de asignar producto" do
    sync = InventorySync.create!(from_date: Date.current, to_date: Date.current, status: "pending_review")
    InventoryMovement.create!(
      inventory_sync: sync, movement_type: "entry", source: "synced", status: "unresolved",
      quantity: 1, order_number: "2-00001", product_name_raw: "Producto sin asignar"
    )

    get inventory_sync_url(sync)

    assert_response :success
    assert_select "#bulkAssignProductModal"
    assert_select "[data-sync-review-target=bulkAssignBtn]"
  end

  test "bulk_assign_product asigna el producto y resuelve solo los ítems no resueltos seleccionados" do
    sync = InventorySync.create!(from_date: Date.current, to_date: Date.current, status: "pending_review", unresolved_count: 2)
    product = products(:one)
    pending = InventoryMovement.create!(
      inventory_sync: sync, movement_type: "entry", source: "synced", status: "unresolved",
      quantity: 1, order_number: "2-00001", product_name_raw: "Producto sin asignar"
    )
    already_resolved = InventoryMovement.create!(
      inventory_sync: sync, movement_type: "entry", source: "synced", status: "resolved",
      quantity: 1, order_number: "2-00002", product: products(:two)
    )

    post bulk_assign_product_inventory_sync_url(sync), params: {
      movement_ids: [pending.id, already_resolved.id],
      product_id: product.id
    }

    assert_redirected_to inventory_sync_path(sync)
    pending.reload
    assert_equal "resolved", pending.status
    assert_equal product.id, pending.product_id
    assert_equal products(:two).id, already_resolved.reload.product_id, "no debe tocar ítems ya resueltos"
    assert_equal 0, sync.reload.unresolved_count
  end

  test "bulk_assign_product sin producto redirige con alerta" do
    sync = InventorySync.create!(from_date: Date.current, to_date: Date.current, status: "pending_review")
    movement = InventoryMovement.create!(
      inventory_sync: sync, movement_type: "entry", source: "synced", status: "unresolved",
      quantity: 1, order_number: "2-00001", product_name_raw: "Producto sin asignar"
    )

    post bulk_assign_product_inventory_sync_url(sync), params: { movement_ids: [movement.id], product_id: "" }

    assert_redirected_to inventory_sync_path(sync)
    assert_equal "unresolved", movement.reload.status
  end
end
