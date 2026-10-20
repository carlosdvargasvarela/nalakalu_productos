require "test_helper"

class BulkMergeTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup { sign_in users(:revisor) }

  def merge(kind, ids, target, extra = {})
    post bulk_url(kind), params: {ids: ids, bulk_action: "merge", confirmed: "1", target_id: target.id, return_to: "/x"}.merge(extra)
  end

  def batch_of(type) = ChangeLog.where(record_type: type).order(:id).last.batch_id

  test "unir familias: los productos pasan conservando sus reglas, el destino suma los tipos sin propagarlos y las otras quedan ocultas" do
    t1, t2 = VariantType.create!(name: "T1"), VariantType.create!(name: "T2")
    a = Family.create!(name: "Bancos")
    b = Family.create!(name: "Banquetas")
    a.family_variant_rules.create!(variant_type: t1, position: 1)
    b.family_variant_rules.create!(variant_type: t2, position: 1)
    pa = Product.create!(name: "PA", base_code: "PA"); pa.update_columns(family_id: a.id)
    pb = Product.create!(name: "PB", base_code: "PB"); pb.update_columns(family_id: b.id)
    rule_pb = pb.product_variant_rules.create!(variant_type: t2, position: 1)
    rules_pa_before = pa.product_variant_rules.pluck(:variant_type_id)

    merge("family", [a.id, b.id], a)

    assert_redirected_to "/x"
    assert_equal [a.id, a.id], [pa, pb].map { _1.reload.family_id }
    assert_equal [t1.id, t2.id], a.reload.family_variant_rules.order(:position).pluck(:variant_type_id)
    assert_equal rules_pa_before, pa.reload.product_variant_rules.pluck(:variant_type_id), "los productos del destino no reciben tipos que no tenían"
    assert_equal [rule_pb.id], pb.product_variant_rules.pluck(:id), "el producto movido conserva sus reglas"
    assert_not b.reload.active
    assert a.active

    post undo_change_url(batch_of("Family"))
    assert_equal [a.id, b.id], [pa, pb].map { _1.reload.family_id }
    assert_equal [t1.id], a.reload.family_variant_rules.pluck(:variant_type_id)
    assert_equal [rule_pb.id], pb.reload.product_variant_rules.pluck(:id), "deshacer no se lleva las reglas de los productos"
    assert b.reload.active
  end

  test "unir tipos de variante: re-apunta productos y familias sin perder variantes permitidas y funde reglas duplicadas" do
    s = VariantType.create!(name: "Telas viejas")
    t = VariantType.create!(name: "Telas")
    vs = Variant.create!(variant_type: s, name: "Lino", active: false)
    vt = Variant.create!(variant_type: t, name: "Algodón", active: false)
    p = Product.create!(name: "P", base_code: "P1")     # usa solo S
    q = Product.create!(name: "Q", base_code: "Q1")     # usa S y T
    rule_p = p.product_variant_rules.create!(variant_type: s, position: 1)
    rule_qs = q.product_variant_rules.create!(variant_type: s, position: 1)
    rule_qt = q.product_variant_rules.create!(variant_type: t, position: 2)
    [rule_p, rule_qs, rule_qt].each { |r| Compatibility.where(compatible: r).delete_all }
    Compatibility.create!(variant: vs, compatible: rule_p)
    Compatibility.create!(variant: vs, compatible: rule_qs)
    Compatibility.create!(variant: vt, compatible: rule_qt)
    fam = Family.create!(name: "F")
    fam.family_variant_rules.create!(variant_type: s, position: 1)
    fr = fam.family_variant_rules.first

    merge("variant_type", [s.id, t.id], t)

    assert_equal [t.id, t.id], [vs, vt].map { _1.reload.variant_type_id }
    assert_equal t.id, rule_p.reload.variant_type_id, "la regla de P ahora es del tipo final"
    assert_equal [vs.id], rule_p.compatibilities.pluck(:variant_id), "P conserva la variante que tenía permitida"
    assert_equal [vs.id, vt.id].sort, rule_qt.reload.compatibilities.pluck(:variant_id).sort, "Q: las dos reglas se funden en una"
    assert_nil ProductVariantRule.find_by(id: rule_qs.id)
    assert_equal t.id, fr.reload.variant_type_id
    assert_not s.reload.active
    assert t.active

    post undo_change_url(batch_of("VariantType"))
    assert_equal [s.id, t.id], [vs, vt].map { _1.reload.variant_type_id }
    assert_equal s.id, rule_p.reload.variant_type_id
    assert ProductVariantRule.exists?(rule_qs.id)
    assert_equal [vs.id], rule_qs.reload.compatibilities.pluck(:variant_id)
    assert_equal [vt.id], rule_qt.reload.compatibilities.pluck(:variant_id)
    assert s.reload.active
  end

  test "unir proveedores mueve las piezas; si hay códigos repetidos no cambia nada" do
    a, b = providers(:one), providers(:two)
    SupplierItem.create!(provider: a, name: "X", sku: "S1")
    ib = SupplierItem.create!(provider: b, name: "Y", sku: "S2")
    merge("provider", [a.id, b.id], a)
    assert_equal a.id, ib.reload.provider_id
    assert_not b.reload.active

    SupplierItem.create!(provider: b.tap { _1.update!(active: true) }, name: "Z", sku: "S1") # mismo código que el de a
    merge("provider", [a.id, b.id], a)
    assert_match "mismo código", flash[:alert].to_s
    assert b.reload.active, "todo o nada: no quedó a medias"
  end

  test "la pantalla de confirmación pide elegir cuál se conserva y exige al menos 2" do
    a, b = Family.create!(name: "A"), Family.create!(name: "B")
    2.times { |i| Product.create!(name: "P#{i}", base_code: "P#{i}").update_columns(family_id: b.id) }
    post bulk_url("family"), params: {ids: [a.id, b.id], bulk_action: "merge", return_to: "/x"}
    assert_response :success
    assert_select "input[type=radio][name=target_id]", count: 2
    assert_select "input[type=radio][name=target_id][checked][value=?]", b.id.to_s # propone el que tiene más productos
    assert_match "Unir 2 familias", response.body

    post bulk_url("family"), params: {ids: [a.id], bulk_action: "merge", return_to: "/x"}
    assert_redirected_to "/x"
    assert_match "al menos 2", flash[:alert]
  end

  test "unir no aplica a productos, el destino debe estar entre los elegidos y se puede renombrar" do
    p1, p2 = Product.create!(name: "A", base_code: "A1"), Product.create!(name: "B", base_code: "B1")
    post bulk_url("product"), params: {ids: [p1.id, p2.id], bulk_action: "merge", return_to: "/x"}
    assert_match "solo aplica", flash[:alert]

    a, b, c = %w[A B C].map { Family.create!(name: _1) }
    merge("family", [a.id, b.id], c)
    assert_match "Elige cuál", flash[:alert]
    assert a.reload.active && b.reload.active

    merge("family", [a.id, b.id], a, new_name: "Banquetas y bancos")
    assert_equal "Banquetas y bancos", a.reload.name
  end

  test "la barra de grupos tiene el botón Unir y la de productos no" do
    Family.create!(name: "F")
    get families_url
    assert_select "#bulk-form button[name=bulk_action][value=merge]", count: 1
    get variant_types_url
    assert_select "#bulk-form button[name=bulk_action][value=merge]", count: 1
    get products_url
    assert_select "#bulk-form button[name=bulk_action][value=merge]", count: 0
  end
end
