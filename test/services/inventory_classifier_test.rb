# test/services/inventory_classifier_test.rb
require "test_helper"

class InventoryClassifierTest < ActiveSupport::TestCase
  def item(name, qty = 1)
    { "id" => rand(100_000), "product_name" => name, "quantity_delivered" => qty }
  end

  def delivery(order_number:, client_name: "Cliente Genérico", items: [], source_showroom: nil, destination_showroom: nil)
    {
      "order_number" => order_number,
      "client" => { "name" => client_name },
      "items" => items,
      "source_showroom" => source_showroom,
      "destination_showroom" => destination_showroom
    }
  end

  test "usa destination_showroom estructurado como sala de entrada cuando el código es conocido" do
    d = delivery(
      order_number: "MOV-001",
      items: [item("Sofá 3 puestos")],
      destination_showroom: { "id" => 1, "name" => "Sala Escazú", "code" => "SE" }
    )

    results = InventoryClassifier.classify(d)
    entries = results.select { |r| r.type == "entry" }

    assert_equal 1, entries.size
    assert_equal "SE", entries.first.sala
  end

  test "usa source_showroom estructurado como (única) sala de salida cuando el código es conocido" do
    d = delivery(
      order_number: "MOV-002",
      items: [item("Sofá 3 puestos")],
      source_showroom: { "id" => 2, "name" => "Sala Palmares", "code" => "SP" }
    )

    results = InventoryClassifier.classify(d)
    exits = results.select { |r| r.type == "exit" }

    assert_equal 1, exits.size
    assert_equal "SP", exits.first.sala
  end

  test "cae al regex cuando el showroom estructurado es null" do
    d = delivery(
      order_number: "MOV-003",
      client_name: "Juan en Guanacaste",
      items: [item("Sofá 3 puestos")],
      destination_showroom: nil,
      source_showroom: nil
    )

    results = InventoryClassifier.classify(d)
    entries = results.select { |r| r.type == "entry" }

    assert_equal 1, entries.size
    assert_equal "SG", entries.first.sala, "debe seguir detectando por nombre de cliente cuando no hay dato estructurado"
  end

  test "cae al regex cuando el código del showroom estructurado no es una sala conocida" do
    d = delivery(
      order_number: "MOV-004",
      items: [item("tomar de SE"), item("Silla comedor")],
      source_showroom: { "id" => 9, "name" => "Bodega Central", "code" => "BOD" },
      destination_showroom: nil
    )

    results = InventoryClassifier.classify(d)
    exits = results.select { |r| r.type == "exit" }

    assert_equal 1, exits.size
    assert_equal "SE", exits.first.sala, "código de showroom no rastreado en inventario -> usar regex de respaldo"
  end

  test "entregas a clientes (PED-) sin destination_showroom no generan entrada" do
    d = delivery(
      order_number: "PED-12345",
      items: [item("Sofá 3 puestos")],
      destination_showroom: nil
    )

    results = InventoryClassifier.classify(d)
    assert results.none? { |r| r.type == "entry" }
  end
end
