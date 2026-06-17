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
    assert_includes sync.errors[:kind], "is not included in the list"
  end

  test "stores import_errors as an array" do
    sync = InventorySync.create!(
      from_date: Date.current, to_date: Date.current, status: "pending_review",
      kind: "bulk_upload", import_errors: ["Fila 3: sala no encontrada."]
    )
    assert_equal ["Fila 3: sala no encontrada."], sync.reload.import_errors
  end
end
