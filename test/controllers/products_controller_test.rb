require "test_helper"
require "minitest/mock"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:admin)
    @product = products(:one)
  end

  test "should get index" do
    get products_url
    assert_response :success
  end

  test "should get new" do
    get new_product_url
    assert_response :success
  end

  test "should create product" do
    assert_difference("Product.count") do
      post products_url, params: { product: { active: @product.active, base_code: "PRODUCT-NUEVO", name: "Producto Nuevo" } }
    end

    assert_redirected_to products_path(selected_id: Product.last.id)
  end

  test "crear producto no falla aunque el broadcast de ActionCable falle (ej. Redis mal configurado)" do
    broken_server = Object.new
    def broken_server.broadcast(*)
      raise "connection refused"
    end

    ActionCable.stub :server, broken_server do
      assert_difference("Product.count") do
        post products_url, params: { product: { active: @product.active, base_code: "PRODUCT-RESILIENTE", name: "Producto Resiliente" } }
      end
    end

    assert_redirected_to products_path(selected_id: Product.last.id)
  end

  test "should show product" do
    get product_url(@product)
    assert_response :success
  end

  test "should get edit" do
    get edit_product_url(@product)
    assert_response :success
  end

  test "should update product" do
    patch product_url(@product), params: { product: { active: @product.active, base_code: @product.base_code, name: @product.name } }
    assert_redirected_to products_path(selected_id: @product.id)
  end

  test "should destroy product" do
    assert_difference("Product.count", -1) do
      delete product_url(@product)
    end

    assert_redirected_to products_url
  end

  test "bulk_activate activa los productos seleccionados y preserva los filtros" do
    @product.update!(active: false)

    patch bulk_activate_products_url, params: { ids: [@product.id], search: "abc", status: "inactive" }

    assert @product.reload.active?
    assert_redirected_to products_path(search: "abc", status: "inactive")
  end

  test "bulk_deactivate desactiva los productos seleccionados" do
    @product.update!(active: true)

    patch bulk_deactivate_products_url, params: { ids: [@product.id] }

    assert_not @product.reload.active?
  end

  test "bulk_activate sin selección redirige con alerta" do
    patch bulk_activate_products_url, params: { ids: [] }
    assert_redirected_to products_path
    assert_equal "No seleccionaste ningún producto.", flash[:alert]
  end
end
