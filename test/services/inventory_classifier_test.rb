# test/services/inventory_classifier_test.rb
require "test_helper"

class InventoryClassifierTest < ActiveSupport::TestCase
  def item(name, qty = 1)
    { "id" => rand(100_000), "product_name" => name, "quantity_delivered" => qty }
  end

  def delivery(order_number:, items: [], source_showroom: nil, destination_showroom: nil)
    {
      "order_number" => order_number,
      "items" => items,
      "source_showroom" => source_showroom,
      "destination_showroom" => destination_showroom
    }
  end

  setup do
    @palmares   = showrooms(:palmares)
    @escazu     = showrooms(:escazu)
    @guanacaste = showrooms(:guanacaste)
  end

  test "genera entrada cuando la entrega trae destination_showroom estructurado y conocido" do
    d = delivery(
      order_number: "MOV-001",
      items: [item("Sofá 3 puestos")],
      destination_showroom: { "id" => 1, "name" => @escazu.name, "code" => @escazu.code }
    )

    entries = InventoryClassifier.classify(d).select { |r| r.type == "entry" }

    assert_equal 1, entries.size
    assert_equal @escazu, entries.first.showroom
  end

  test "genera salida cuando la entrega trae source_showroom estructurado y conocido" do
    d = delivery(
      order_number: "MOV-002",
      items: [item("Sofá 3 puestos")],
      source_showroom: { "id" => 2, "name" => @palmares.name, "code" => @palmares.code }
    )

    exits = InventoryClassifier.classify(d).select { |r| r.type == "exit" }

    assert_equal 1, exits.size
    assert_equal @palmares, exits.first.showroom
  end

  test "puede generar entrada y salida simultáneas cuando ambos showrooms vienen estructurados" do
    d = delivery(
      order_number: "MOV-003",
      items: [item("Sofá 3 puestos")],
      source_showroom: { "id" => 2, "name" => @palmares.name, "code" => @palmares.code },
      destination_showroom: { "id" => 1, "name" => @escazu.name, "code" => @escazu.code }
    )

    results = InventoryClassifier.classify(d)

    assert_equal 1, results.count { |r| r.type == "exit" && r.showroom == @palmares }
    assert_equal 1, results.count { |r| r.type == "entry" && r.showroom == @escazu }
  end

  test "ignora showrooms estructurados con código que no corresponde a ninguna sala activa" do
    d = delivery(
      order_number: "MOV-004",
      items: [item("Silla comedor")],
      source_showroom: { "id" => 9, "name" => "Bodega Central", "code" => "BOD" }
    )

    assert InventoryClassifier.classify(d).none? { |r| r.type == "exit" }
  end

  test "genera entrada a la sala principal cuando el order_number coincide con sus prefijos configurados" do
    d = delivery(
      order_number: "2-00045",
      items: [item("Sofá 3 puestos"), item("Mesa de centro")]
    )

    entries = InventoryClassifier.classify(d).select { |r| r.type == "entry" }

    assert_equal 2, entries.size
    assert entries.all? { |r| r.showroom == @palmares }
  end

  test "no genera entrada de reabastecimiento si el order_number no coincide con los prefijos de la sala principal" do
    @palmares.update!(order_number_prefixes: ["9"])

    d = delivery(order_number: "2-00045", items: [item("Sofá 3 puestos")])

    assert InventoryClassifier.classify(d).none? { |r| r.type == "entry" }
  end

  test "ambas reglas son independientes: pueden disparar movimientos distintos para la misma entrega" do
    d = delivery(
      order_number: "2-00099",
      items: [item("Sofá 3 puestos")],
      source_showroom: { "id" => 2, "name" => @escazu.name, "code" => @escazu.code }
    )

    results = InventoryClassifier.classify(d)

    assert_equal 1, results.count { |r| r.type == "exit"  && r.showroom == @escazu }
    assert_equal 1, results.count { |r| r.type == "entry" && r.showroom == @palmares }
  end

  test "ignora ítems con cantidad entregada cero o negativa" do
    d = delivery(
      order_number: "2-00100",
      items: [item("Sofá 3 puestos", 0), item("Mesa de centro", -1)],
      destination_showroom: { "id" => 1, "name" => @escazu.name, "code" => @escazu.code }
    )

    assert_empty InventoryClassifier.classify(d)
  end

  test "genera salida por palabra clave de producto cuando el pedido matchea un prefijo de salida configurado" do
    InventorySyncConfig.current.update!(exit_order_prefixes: ["PED-4", "PED-5"])
    @escazu.update!(product_keywords: ["VENDIDO SALA SE"])

    d = delivery(order_number: "PED-4-00123", items: [item("Sofá 3 puestos VENDIDO SALA SE")])

    exits = InventoryClassifier.classify(d).select { |r| r.type == "exit" }

    assert_equal 1, exits.size
    assert_equal @escazu, exits.first.showroom
  end

  test "no genera nada por palabra clave si el order_number no matchea ningún prefijo de salida" do
    InventorySyncConfig.current.update!(exit_order_prefixes: ["PED-4"])
    @escazu.update!(product_keywords: ["VENDIDO SALA SE"])

    d = delivery(order_number: "2-00045", items: [item("Sofá 3 puestos VENDIDO SALA SE")])

    assert InventoryClassifier.classify(d).none? { |r| r.type == "exit" }
  end

  test "no genera nada por palabra clave si ningún producto matchea ninguna palabra clave" do
    InventorySyncConfig.current.update!(exit_order_prefixes: ["PED-4"])
    @escazu.update!(product_keywords: ["VENDIDO SALA SE"])

    d = delivery(order_number: "PED-4-00123", items: [item("Sofá 3 puestos")])

    assert_empty InventoryClassifier.classify(d)
  end

  test "deja la sala ambigua (nil) cuando el producto matchea palabras clave de más de una sala" do
    InventorySyncConfig.current.update!(exit_order_prefixes: ["PED-4"])
    @escazu.update!(product_keywords: ["VENDIDO"])
    @guanacaste.update!(product_keywords: ["VENDIDO"])

    d = delivery(order_number: "PED-4-00123", items: [item("Sofá 3 puestos VENDIDO")])

    exits = InventoryClassifier.classify(d).select { |r| r.type == "exit" }

    assert_equal 1, exits.size
    assert_nil exits.first.showroom
  end

  test "la regla de palabra clave es independiente de las reglas 1 y 2" do
    InventorySyncConfig.current.update!(exit_order_prefixes: ["PED-4"])
    @escazu.update!(product_keywords: ["VENDIDO SALA SE"])

    d = delivery(
      order_number: "PED-4-00123",
      items: [item("Sofá 3 puestos VENDIDO SALA SE")],
      destination_showroom: { "id" => 1, "name" => @palmares.name, "code" => @palmares.code }
    )

    results = InventoryClassifier.classify(d)

    assert_equal 1, results.count { |r| r.type == "exit"  && r.showroom == @escazu }
    assert_equal 1, results.count { |r| r.type == "entry" && r.showroom == @palmares }
  end
end
