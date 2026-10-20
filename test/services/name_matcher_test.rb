require "test_helper"

class NameMatcherTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
    @tipo = VariantType.create!(name: "Tiraderas")
    @v10 = Variant.create!(variant_type: @tipo, name: "TIRADERA 10", active: false)
    @v09 = Variant.create!(variant_type: @tipo, name: "TIRADERA 09", active: false)
    @blanco = Variant.create!(variant_type: VariantType.create!(name: "Colores"), name: "BLANCO", active: false)
    @prov = providers(:one)
    @p10 = SupplierItem.create!(provider: @prov, name: "Tiradera Cerámica Beige/Blanca (TIR-10)", sku: "TIRCER010")
    @p09 = SupplierItem.create!(provider: @prov, name: "Tiradera Cerámica negra (TIR-09)", sku: "TIRCER009")
    @mel = SupplierItem.create!(provider: @prov, name: "Melamina Blanco Mate 18mm", sku: "MEL1")
  end

  def matcher = NameMatcher.new

  test "tokens: sin tildes, singular y sin palabras vacías" do
    assert_equal %w[tiradera ceramica beige blanca tir 10], NameMatcher.tokens("Tiradera Cerámica Beige/Blanca (TIR-10)")
    assert_equal %w[mesa comedor], NameMatcher.tokens("Mesa de Comedor")
    assert_equal %w[tiradera], NameMatcher.tokens("Tiraderas")
  end

  test "variante -> piezas: el nombre corto contenido en el largo, con el número correcto" do
    assert_equal [@p10.id], matcher.pieces_for_variant(@v10).map { _1.record.id }
    assert_equal [@p09.id], matcher.pieces_for_variant(@v09).map { _1.record.id }
    assert_equal 100, matcher.pieces_for_variant(@v10).first.percent
  end

  test "una palabra suelta (color) no basta para sugerir" do
    assert_empty matcher.pieces_for_variant(@blanco)
  end

  test "pieza -> variantes y productos parecidos" do
    prod = Product.create!(name: "Tiradera Cerámica Beige", base_code: "TC1")
    kinds = matcher.targets_for_piece(@p10).map { _1.record.class.name }
    assert_includes kinds, "Variant"
    assert_includes kinds, "Product"
    assert_equal @v10.id, matcher.targets_for_piece(@p10).find { _1.record.is_a?(Variant) }.record.id
  end

  test "tolera typos en palabras largas" do
    v = Variant.create!(variant_type: @tipo, name: "OAKLAND 11", active: false)
    item = SupplierItem.create!(provider: @prov, name: "Tela importada Oackland 11", sku: "TEL1")
    assert_equal [item.id], matcher.pieces_for_variant(v).map { _1.record.id }
  end

  test "no sugiere lo que ya está vinculado" do
    SupplierLink.create!(supplier_item: @p10, variant: @v10)
    assert_empty matcher.pieces_for_variant(@v10)
    assert_empty matcher.targets_for_piece(@p10).select { _1.record == @v10 }
  end

  test "un número que falta en la pieza resta certeza pero sugiere; un número distinto descarta" do
    tipo = VariantType.create!(name: "Cintas")
    v = Variant.create!(variant_type: tipo, name: "Verde Mineral 9046", active: false)
    sin_numero = SupplierItem.create!(provider: @prov, name: "Cinta de Polipropileno de 50mm Verde Mineral (rollo 25mts)", sku: "CIN14")
    otro_numero = SupplierItem.create!(provider: @prov, name: "Cinta de Polipropileno de 50mm Full Verde Mineral 9309 (rollo 25mts)", sku: "CIN19")
    mismo = SupplierItem.create!(provider: @prov, name: "Cinta Verde Mineral 9046", sku: "CIN20")
    got = matcher.pieces_for_variant(v)
    assert_equal [mismo.id, sin_numero.id], got.map { _1.record.id }, "el que trae el mismo número va primero; el de 9309 no aparece"
    assert_operator got.last.percent, :<, got.first.percent
    assert_not_includes got.map { _1.record.id }, otro_numero.id
  end
end
