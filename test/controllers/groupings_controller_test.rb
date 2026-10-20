require "test_helper"

class GroupingsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup { sign_in users(:revisor) }

  test "dividir familia: los elegidos pasan a una familia nueva con las mismas reglas y conservan las suyas" do
    fam = Family.create!(name: "Mesas")
    fam.family_variant_rules.create!(variant_type: variant_types(:one), position: 1)
    a = Product.create!(name: "A", base_code: "A")
    b = Product.create!(name: "B", base_code: "B")
    [a, b].each { _1.update_columns(family_id: fam.id) }
    rule = a.product_variant_rules.create!(variant_type: variant_types(:two), position: 1)

    post reorganize_url("family", fam), params: {dest: "new", new_name: "Mesas altas", child_ids: [a.id]}

    nueva = Family.find_by!(name: "Mesas altas")
    assert_redirected_to family_path(nueva)
    assert_equal nueva.id, a.reload.family_id
    assert_equal fam.id, b.reload.family_id
    assert_equal [variant_types(:one).id], nueva.family_variant_rules.pluck(:variant_type_id)
    assert_equal [rule.id], a.product_variant_rules.pluck(:id), "mover no debe borrar las reglas del producto"
  end

  test "desagrupar deja los productos sin familia" do
    fam = Family.create!(name: "Mesas")
    p = Product.create!(name: "A", base_code: "A")
    p.update_columns(family_id: fam.id)
    post reorganize_url("family", fam), params: {dest: "none", child_ids: [p.id]}
    assert_nil p.reload.family_id
  end

  test "mover piezas a otro proveedor" do
    item = SupplierItem.create!(provider: providers(:one), name: "Pieza")
    post reorganize_url("provider", providers(:one)), params: {dest: "existing", target_id: providers(:two).id, child_ids: [item.id]}
    assert_equal providers(:two).id, item.reload.provider_id
  end

  test "dividir tipo de variante conserva las variantes permitidas en cada producto" do
    tipo = VariantType.create!(name: "Textiles")
    v1 = Variant.create!(variant_type: tipo, name: "T1", active: false)
    v2 = Variant.create!(variant_type: tipo, name: "T2", active: false)
    prod = Product.create!(name: "A", base_code: "A")
    rule = prod.product_variant_rules.create!(variant_type: tipo, position: 1, label: "TE")
    [v1, v2].each { Compatibility.create!(variant: _1, compatible: rule) }

    post reorganize_url("variant_type", tipo), params: {dest: "new", new_name: "Textiles lino", carry_to_products: "1", child_ids: [v1.id]}

    nuevo = VariantType.find_by!(name: "Textiles lino")
    assert_equal nuevo.id, v1.reload.variant_type_id
    assert_equal tipo.id, v2.reload.variant_type_id
    assert_equal [v2.id], rule.compatibilities.pluck(:variant_id)
    nr = prod.product_variant_rules.find_by!(variant_type: nuevo)
    assert_equal [v1.id], nr.compatibilities.pluck(:variant_id)
    assert_equal "TE", nr.label
    assert_not nr.required
  end

  test "nombre repetido no cambia nada" do
    fam = Family.create!(name: "Mesas")
    post reorganize_url("family", fam), params: {dest: "new", new_name: "Mesas", child_ids: []}
    assert_redirected_to reorganize_path("family", fam)
    assert_equal 1, Family.where(name: "Mesas").count
  end

  test "duplicar producto copia reglas y variantes permitidas" do
    p = Product.create!(name: "Mesa", base_code: "M")
    rule = p.product_variant_rules.create!(variant_type: variant_types(:one), position: 1)
    Compatibility.where(compatible: rule).delete_all
    Compatibility.create!(variant: variants(:one), compatible: rule)
    assert_difference("Product.count", 1) { post duplicate_product_url(p) }
    copy = Product.find_by!(name: "#{p.name} (copia)")
    assert_redirected_to edit_product_path(copy)
    assert_equal [variants(:one).id], copy.product_variant_rules.first.compatibilities.pluck(:variant_id)
  end

  test "duplicar variante copia sus compatibilidades" do
    v = Variant.create!(variant_type: variant_types(:one), name: "Original", active: false)
    Compatibility.create!(variant: v, compatible: variants(:two))
    post duplicate_variant_url(v)
    copy = Variant.find_by!(name: "Original (copia)")
    assert_equal [[variants(:two).id, "Variant"]], copy.compatibilities.pluck(:compatible_id, :compatible_type)
  end

  test "la pantalla de reorganizar carga" do
    get reorganize_url("variant_type", variant_types(:one))
    assert_response :success
  end

  test "unir: mueve todo a otro grupo y oculta el origen sin borrarlo" do
    a = Family.create!(name: "A")
    b = Family.create!(name: "B")
    p = Product.create!(name: "P", base_code: "P")
    p.update_columns(family_id: a.id)
    post reorganize_url("family", a), params: {dest: "existing", target_id: b.id, hide_source: "1", child_ids: [p.id]}
    assert_equal b.id, p.reload.family_id
    assert_not a.reload.active
    get families_url
    assert_no_match(/>A</, response.body)
    get families_url(hidden: "1")
    assert_match(/Oculto/, response.body)
  end
end
