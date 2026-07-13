require "test_helper"

class ProductDecoderTest < ActiveSupport::TestCase
  setup do
    ProductDecoder.clear_cache!

    @sofa = Product.create!(name: "Sofá Cama Oslo 3 plazas", base_code: "SOF-OSLO", active: true)
    @banco_bar = Product.create!(name: "Banco Costa (Bar)", base_code: "BAN-COSTA-BAR", active: true)
    @banco_cocina = Product.create!(name: "Banco Costa (Cocina)", base_code: "BAN-COSTA-COC", active: true)
    @inactive = Product.create!(name: "Silla Descontinuada", base_code: "SIL-OLD", active: false)

    @color = VariantType.create!(name: "Color", procurement_strategy: "individual")
    ProductVariantRule.create!(product: @sofa, variant_type: @color, position: 1)
    @gris = Variant.create!(variant_type: @color, name: "Gris", code: "GR", active: true)
    @azul = Variant.create!(variant_type: @color, name: "Azul", code: "AZ", active: true)
  end

  teardown { ProductDecoder.clear_cache! }

  test "detecta un match exacto" do
    result = ProductDecoder.decode("Sofá Cama Oslo 3 plazas")
    assert_equal @sofa, result.base_product
  end

  test "tolera acentos y mayúsculas" do
    result = ProductDecoder.decode("SOFA CAMA OSLO 3 PLAZAS")
    assert_equal @sofa, result.base_product
  end

  test "tolera un typo en el nombre" do
    result = ProductDecoder.decode("sofa kama oslo 3 plazas")
    assert_equal @sofa, result.base_product
  end

  test "distingue productos casi idénticos por su sufijo" do
    assert_equal @banco_bar, ProductDecoder.decode("Banco Costa Bar").base_product
    assert_equal @banco_cocina, ProductDecoder.decode("banco costa cocina").base_product
  end

  test "no confunde texto sin relación con un producto real" do
    result = ProductDecoder.decode("xyz materiales de oficina factura 4021")
    assert_nil result.base_product
  end

  # Limitación conocida: Dice's Coefficient compara el string completo, así que
  # texto irrelevante alrededor de un nombre abreviado diluye el score por debajo
  # del umbral. No es una regresión nueva — solo queda documentada acá.
  test "texto abreviado con mucho ruido alrededor puede quedar sin resolver" do
    result = ProductDecoder.decode("sofa oslo 3p gris - pedido urgente cliente frecuente")
    assert_nil result.base_product
  end

  test "no detecta productos inactivos" do
    assert_nil ProductDecoder.decode("Silla Descontinuada").base_product
  end

  test "detecta variantes de color en el texto restante" do
    result = ProductDecoder.decode("Sofá Cama Oslo 3 plazas gris")
    assert_equal @sofa, result.base_product
    assert result.has_variants
    assert_includes result.variants, @gris
    assert_not_includes result.variants, @azul
  end

  test "decode con string en blanco no rompe y devuelve resultado vacío" do
    result = ProductDecoder.decode("")
    assert_nil result.base_product
    assert_not result.has_variants
  end

  test "detect_base_product usa la caché de productos activos (fuzzy_match)" do
    matcher = ProductDecoder.product_matcher
    assert_kind_of FuzzyMatch, matcher
    assert_equal @sofa, ProductDecoder.detect_base_product("sofa oslo")
  end
end
