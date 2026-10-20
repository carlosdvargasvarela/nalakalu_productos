require "test_helper"

class ChangesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup { sign_in users(:revisor) }

  test "editar un producto queda en el historial y se puede deshacer" do
    p = Product.create!(name: "Mesa", base_code: "M", list_price: 100)
    patch product_url(p), params: {product: {list_price: "250"}}
    assert_equal 250, p.reload.list_price
    log = ChangeLog.where(record_type: "Product", record_id: p.id, action: "update").last
    assert_equal({"list_price" => "100.0"}, log.before_data.transform_values(&:to_s).slice("list_price"))

    get changes_url(type: "Product", id: p.id)
    assert_response :success
    post undo_change_url(log.batch_id)
    assert_equal 100, p.reload.list_price
    assert log.reload.undone_at
  end

  test "borrar y deshacer restaura el registro con su id" do
    v = Variant.create!(variant_type: variant_types(:one), name: "Borrame", active: false)
    delete variant_url(v)
    assert_nil Variant.find_by(id: v.id)
    batch = ChangeLog.where(record_type: "Variant", record_id: v.id, action: "destroy").last.batch_id
    post undo_change_url(batch)
    assert_equal "Borrame", Variant.find(v.id).name
  end

  test "no se puede deshacer si hubo un cambio posterior" do
    p = Product.create!(name: "Mesa", base_code: "M", list_price: 100)
    patch product_url(p), params: {product: {list_price: "250"}}
    first = ChangeLog.where(record_type: "Product", record_id: p.id).last.batch_id
    patch product_url(p), params: {product: {list_price: "300"}}
    post undo_change_url(first)
    assert_equal 300, p.reload.list_price
    assert_nil ChangeLog.find_by(batch_id: first).undone_at
  end

  test "deshacer una reorganización de tipo de variante restaura variantes, compatibilidades y reglas" do
    tipo = VariantType.create!(name: "Textiles")
    v1 = Variant.create!(variant_type: tipo, name: "T1", active: false)
    prod = Product.create!(name: "A", base_code: "A")
    rule = ProductVariantRule.create!(product: prod, variant_type: tipo, position: 1)
    Compatibility.where(compatible: rule).delete_all
    Compatibility.create!(variant: v1, compatible: rule)

    post reorganize_url("variant_type", tipo), params: {dest: "new", new_name: "Lino", carry_to_products: "1", child_ids: [v1.id]}
    assert_equal "Lino", v1.reload.variant_type.name
    batch = ChangeLog.where(record_type: "VariantType", action: "create").last.batch_id

    post undo_change_url(batch)
    assert_equal tipo.id, v1.reload.variant_type_id
    assert_nil VariantType.find_by(name: "Lino")
    assert_equal [v1.id], rule.reload.compatibilities.pluck(:variant_id)
    assert_equal [rule.id], prod.product_variant_rules.pluck(:id)
  end

  test "deshacer mover productos entre familias" do
    fam = Family.create!(name: "Mesas")
    p = Product.create!(name: "A", base_code: "A")
    p.update_columns(family_id: fam.id)
    post reorganize_url("family", fam), params: {dest: "none", child_ids: [p.id]}
    assert_nil p.reload.family_id
    post undo_change_url(ChangeLog.where(record_type: "Product", record_id: p.id).last.batch_id)
    assert_equal fam.id, p.reload.family_id
  end
end
