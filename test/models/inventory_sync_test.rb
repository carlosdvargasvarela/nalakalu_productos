require "test_helper"

class InventorySyncTest < ActiveSupport::TestCase
  def build_sync(attrs = {})
    InventorySync.new({
      from_date: Date.current, to_date: Date.current, status: "pending_review"
    }.merge(attrs))
  end

  test "defaults kind to logistics_sync and import_errors to empty array" do
    sync = InventorySync.create!(from_date: Date.current, to_date: Date.current, status: "pending_review")
    assert_equal "logistics_sync", sync.kind
    assert_equal [], sync.import_errors
    assert_not sync.bulk_upload?
  end

  test "accepts kind bulk_upload" do
    sync = build_sync(kind: "bulk_upload")
    assert sync.valid?
    assert sync.bulk_upload?
  end

  test "rejects unknown kind" do
    sync = build_sync(kind: "weird")
    assert_not sync.valid?
    assert_includes sync.errors[:kind], "no está incluido en la lista"
  end

  test "stores import_errors as an array" do
    sync = InventorySync.create!(
      from_date: Date.current, to_date: Date.current, status: "pending_review",
      kind: "bulk_upload", import_errors: ["Fila 3: sala no encontrada."]
    )
    assert_equal ["Fila 3: sala no encontrada."], sync.reload.import_errors
  end

  test "pending_logistics_sync_overlapping encuentra un pendiente que se superpone en fechas" do
    existing = InventorySync.create!(from_date: "2026-06-10", to_date: "2026-06-15", status: "pending_review")

    found = InventorySync.pending_logistics_sync_overlapping("2026-06-14", "2026-06-20")

    assert_equal existing, found
  end

  test "pending_logistics_sync_overlapping ignora rangos que no se tocan" do
    InventorySync.create!(from_date: "2026-06-01", to_date: "2026-06-05", status: "pending_review")

    assert_nil InventorySync.pending_logistics_sync_overlapping("2026-06-10", "2026-06-15")
  end

  test "pending_logistics_sync_overlapping ignora syncs ya confirmados" do
    InventorySync.create!(from_date: "2026-06-10", to_date: "2026-06-15", status: "confirmed")

    assert_nil InventorySync.pending_logistics_sync_overlapping("2026-06-12", "2026-06-13")
  end

  test "pending_logistics_sync_overlapping ignora cargas masivas (bulk_upload)" do
    InventorySync.create!(from_date: "2026-06-10", to_date: "2026-06-15", status: "pending_review", kind: "bulk_upload")

    assert_nil InventorySync.pending_logistics_sync_overlapping("2026-06-12", "2026-06-13")
  end

  test "movement_stats clasifica confirmados, sugeridos, sin asignar e ignorados" do
    sync = InventorySync.create!(from_date: Date.current, to_date: Date.current, status: "pending_review")
    showroom = showrooms(:palmares)
    product  = products(:one)

    InventoryMovement.create!(inventory_sync: sync, movement_type: "entry", source: "synced",
      status: "resolved", showroom: showroom, product: product, quantity: 1, order_number: "1")
    InventoryMovement.create!(inventory_sync: sync, movement_type: "entry", source: "synced",
      status: "unresolved", showroom: showroom, product: product, quantity: 1, order_number: "2")
    InventoryMovement.create!(inventory_sync: sync, movement_type: "entry", source: "synced",
      status: "unresolved", showroom: nil, product: nil, quantity: 1, order_number: "3")
    InventoryMovement.create!(inventory_sync: sync, movement_type: "entry", source: "synced",
      status: "ignored", showroom: showroom, product: product, quantity: 1, order_number: "4")

    assert_equal(
      { confirmed: 1, suggested: 1, unassigned: 1, ignored: 1 },
      sync.movement_stats
    )
  end
end
