require "test_helper"

class InventoryMovementTest < ActiveSupport::TestCase
  setup do
    @showroom = showrooms(:palmares)
    @product  = products(:one)
  end

  def build_movement(attrs = {})
    InventoryMovement.new({
      movement_type: "entry", showroom: @showroom, product: @product,
      quantity: 1, status: "resolved", source: "synced", delivery_date: Date.current
    }.merge(attrs))
  end

  test "valid with default source synced and no flag" do
    movement = build_movement
    assert movement.valid?
    assert_equal "synced", movement.source
    assert_nil movement.flag
  end

  test "accepts manual source and stock_missing flag" do
    movement = build_movement(source: "manual", flag: "stock_missing")
    assert movement.valid?
  end

  test "rejects unknown source" do
    movement = build_movement(source: "imported")
    assert_not movement.valid?
    assert_includes movement.errors[:source], "is not included in the list"
  end

  test "rejects unknown flag but allows nil" do
    movement = build_movement(flag: "weird")
    assert_not movement.valid?
    assert_includes movement.errors[:flag], "is not included in the list"

    assert build_movement(flag: nil).valid?
  end

  test "type_label and source_label read naturally" do
    assert_equal "Entrada", build_movement(movement_type: "entry").type_label
    assert_equal "Salida", build_movement(movement_type: "exit").type_label
    assert_equal "Stock inicial", build_movement(movement_type: "initial").type_label
    assert_equal "Automático", build_movement(source: "synced").source_label
    assert_equal "Manual", build_movement(source: "manual").source_label
  end

  test "stock_by_product_and_showroom groups confirmed+resolved quantities by showroom" do
    other_showroom = showrooms(:escazu)

    InventoryMovement.create!(movement_type: "entry", showroom: @showroom, product: @product,
      quantity: 5, status: "resolved", source: "synced", delivery_date: Date.current)
    InventoryMovement.create!(movement_type: "exit", showroom: other_showroom, product: @product,
      quantity: 2, status: "resolved", source: "synced", delivery_date: Date.current)

    raw = InventoryMovement.stock_by_product_and_showroom

    assert_equal 5, raw[[@product.id, @showroom.id, "entry"]]
    assert_equal 2, raw[[@product.id, other_showroom.id, "exit"]]
  end

  test "flag_if_stock_missing! marca exit con stock insuficiente y deja notes" do
    movement = build_movement(movement_type: "exit", quantity: 3)
    InventoryMovement.flag_if_stock_missing!(movement)

    assert_equal "stock_missing", movement.flag
    assert_match "Alerta automática", movement.notes
  end

  test "flag_if_stock_missing! no marca exit con stock suficiente" do
    InventoryMovement.create!(movement_type: "entry", showroom: @showroom, product: @product,
      quantity: 10, status: "resolved", source: "manual", delivery_date: Date.current)

    movement = build_movement(movement_type: "exit", quantity: 3)
    InventoryMovement.flag_if_stock_missing!(movement)

    assert_nil movement.flag
  end

  test "flag_if_stock_missing! es no-op para movimientos que no son exit" do
    movement = build_movement(movement_type: "entry", quantity: 999)
    InventoryMovement.flag_if_stock_missing!(movement)

    assert_nil movement.flag
  end
end
