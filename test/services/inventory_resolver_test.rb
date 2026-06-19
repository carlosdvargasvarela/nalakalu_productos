require "test_helper"
require "minitest/mock"

class InventoryResolverTest < ActiveSupport::TestCase
  setup do
    @sync = InventorySync.create!(
      from_date: Date.current, to_date: Date.current,
      status: "pending_review", synced_at: Time.current
    )
  end

  def item(name, qty = 1)
    { "id" => rand(1_000_000), "product_name" => name, "quantity_delivered" => qty }
  end

  def delivery(order_number:, items:)
    {
      "id" => rand(100_000),
      "order_number" => order_number,
      "delivery_date" => Date.current.to_s,
      "client" => { "name" => "Cliente Genérico" },
      "items" => items,
      "source_showroom" => nil,
      "destination_showroom" => nil
    }
  end

  test "decodifica cada nombre de producto único una sola vez por corrida, sin importar cuántas entregas/ítems lo repitan" do
    deliveries = [
      delivery(order_number: "2-001", items: [item("Sofá 3 puestos"), item("Mesa de centro")]),
      delivery(order_number: "2-002", items: [item("Sofá 3 puestos"), item("Sofá 3 puestos")]),
      delivery(order_number: "3-003", items: [item("Mesa de centro")])
    ]

    decode_calls = []
    fake_decode = ->(name) {
      decode_calls << name
      ProductDecoder::Result.new(has_variants: false, base_product: nil, variants: [], unrecognized_codes: [])
    }

    ProductDecoder.stub :decode, fake_decode do
      InventoryResolver.resolve_deliveries(deliveries, @sync)
    end

    assert_equal 2, decode_calls.size,
      "ProductDecoder.decode debe invocarse una sola vez por nombre único en toda la corrida"
    assert_includes decode_calls, "Sofá 3 puestos"
    assert_includes decode_calls, "Mesa de centro"
  end

  test "crea el movimiento con showroom_id nil cuando la sala de salida queda ambigua" do
    InventorySyncConfig.current.update!(exit_order_prefixes: ["PED-4"])
    showrooms(:escazu).update!(product_keywords: ["VENDIDO"])
    showrooms(:guanacaste).update!(product_keywords: ["VENDIDO"])

    deliveries = [delivery(order_number: "PED-4-00123", items: [item("Sofá 3 puestos VENDIDO")])]

    movements = InventoryResolver.resolve_deliveries(deliveries, @sync)

    assert_equal 1, movements.size
    assert_nil movements.first.showroom_id
    assert_equal "exit", movements.first.movement_type
    assert_equal "unresolved", movements.first.status
  end
end
