require "test_helper"

class QuickEditsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:revisor)
    @product = Product.create!(name: "Mesa", base_code: "M")
  end

  test "guarda el precio y lo deja en el historial" do
    patch quick_edit_url("product", @product), params: {field: "list_price", value: "1500.5"}, as: :json
    assert_response :success
    assert_equal 1500.5, @product.reload.list_price
    assert ChangeLog.where(record_type: "Product", record_id: @product.id, action: "update").exists?
  end

  test "vacío quita el precio" do
    @product.update!(list_price: 10)
    patch quick_edit_url("product", @product), params: {field: "list_price", value: ""}, as: :json
    assert_nil @product.reload.list_price
  end

  test "error de validación se devuelve para mostrarlo" do
    patch quick_edit_url("product", @product), params: {field: "name", value: ""}, as: :json
    assert_response :unprocessable_entity
    assert_match(/Nombre|blanco/i, response.parsed_body["error"])
  end

  test "solo campos permitidos" do
    patch quick_edit_url("product", @product), params: {field: "family_id", value: "1"}, as: :json
    assert_response :unprocessable_entity
  end

  test "la lista renderiza los campos editables" do
    get products_url
    assert_select "input[data-controller=quick-edit][data-quick-edit-field-value=list_price]"
  end
end
