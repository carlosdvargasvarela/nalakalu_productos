require "test_helper"

class ReviewPanelTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:revisor)
    @fam = Family.create!(name: "Mesas")
  end

  test "el panel muestra las verificaciones y pide confirmar si hay problemas" do
    p = Product.create!(name: "Mesa", base_code: "M1") # sin familia ni precio
    get product_url(p)
    assert_response :success
    assert_match "¿Está listo para Odoo?", response.body
    assert_match "Sin precio de venta", response.body
    assert_match "No tiene familia", response.body
    assert_select "button[data-turbo-confirm*='2 problemas']"
  end

  test "sin problemas no pide confirmación" do
    p = Product.create!(name: "Mesa", base_code: "M1", list_price: 100)
    p.update_columns(family_id: @fam.id)
    get product_url(p)
    assert_match "Sin problemas detectados", response.body
    assert_select "button[data-turbo-confirm]", count: 0
  end

  test "las verificaciones de cada tipo no fallan y distinguen lo que falta" do
    tipo = VariantType.create!(name: "Textiles", own_supplier_code: true)
    v = Variant.create!(variant_type: tipo, name: "T1", active: false)
    levels = ReviewGuide.checks(v).to_h { [_1.text, _1.level] }
    assert_equal :bad, levels["Falta su pieza de proveedor"]
    assert ReviewGuide.checks(tipo).any? { _1.level == :bad && _1.text.include?("sin pieza") }
    item = SupplierItem.create!(provider: providers(:one), name: "Sobre")
    assert_equal [:bad, :bad, :bad], ReviewGuide.checks(item).first(3).map(&:level)
    [Family.create!(name: "Vacía"), providers(:one)].each { assert ReviewGuide.checks(_1).any? }
  end

  test "anterior vuelve al registro previo de la lista" do
    a = Product.create!(name: "AAA", base_code: "A")
    b = Product.create!(name: "BBB", base_code: "B")
    get prev_review_url(type: "Product", before: b.id)
    assert_redirected_to product_path(a)
    get prev_review_url(type: "Product", before: a.id)
    assert_redirected_to products_path
  end

  test "inicio sugiere el primer módulo pendiente y la ayuda carga" do
    get root_url
    assert_match "Siguiente paso sugerido", response.body
    get help_url
    assert_response :success
    assert_match "Guía rápida para revisar", response.body
  end

  test "las filas de las listas abren el detalle" do
    p = Product.create!(name: "Mesa", base_code: "M1")
    get products_url
    assert_select "tr[data-controller=row-link][data-row-link-url-value=?]", product_path(p)
  end

  test "familias: la lista, el detalle y los formularios hablan de variantes, no de estructura de código" do
    fam = Family.create!(name: "Bancos")
    tipo = VariantType.create!(name: "Textiles")
    Variant.create!(variant_type: tipo, name: "Lino", active: false)
    fam.family_variant_rules.create!(variant_type: tipo, position: 1)
    Family.create!(name: "Sin nada")

    get families_url
    assert_match "Textiles", response.body
    assert_match "Sin variantes", response.body

    get family_url(fam)
    assert_match "Variantes de la familia", response.body
    assert_no_match(/Estructura de Código Base/, response.body)

    get edit_family_url(fam)
    assert_match "Agregar tipo de variante", response.body
    assert_match "Opciones avanzadas", response.body
    assert_no_match(/Constructor de Estructura|DNA/, response.body)

    get edit_product_url(Product.create!(name: "P", base_code: "P1"))
    assert_match "Variantes del producto", response.body
    assert_no_match(/Estructura DNA|Agregar Paso/, response.body)
  end
end
