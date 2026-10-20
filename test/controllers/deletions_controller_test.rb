require "test_helper"

class DeletionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup { sign_in users(:revisor) }

  test "la confirmación muestra el impacto" do
    tipo = VariantType.create!(name: "Textiles")
    2.times { |i| Variant.create!(variant_type: tipo, name: "T#{i}", active: false) }
    get confirm_delete_url("variant_type", tipo)
    assert_response :success
    assert_match "variantes que se eliminan junto con el tipo", response.body
    assert_select ".badge.bg-danger", text: "2"
  end

  test "ocultar deja el registro inactivo sin borrarlo" do
    fam = Family.create!(name: "Mesas")
    patch hide_record_url("family", fam)
    assert_not fam.reload.active
  end

  test "eliminar borra, avisa y se puede deshacer" do
    fam = Family.create!(name: "Mesas")
    delete confirm_delete_url("family", fam)
    assert_redirected_to families_path
    assert_nil Family.find_by(id: fam.id)
    post undo_change_url(ChangeLog.where(record_type: "Family", record_id: fam.id, action: "destroy").last.batch_id)
    assert Family.find_by(id: fam.id)
  end

  test "las pantallas de detalle apuntan a la confirmación y no borran directo" do
    p = Product.create!(name: "Mesa", base_code: "M")
    get product_url(p)
    assert_select "a[href=?]", confirm_delete_path("product", p)
  end
end
