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
end
