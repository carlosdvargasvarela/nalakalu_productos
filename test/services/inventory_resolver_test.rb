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
end
