require "test_helper"

class ReviewsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:revisor)
    @product = products(:one)
  end

  test "revisor aprueba, y editar después marca la aprobación como obsoleta" do
    post reviews_url, params: {reviewable_type: "Product", reviewable_id: @product.id, status: "approved"}
    assert_equal "approved", @product.reload.review_status
    assert_not @product.review_stale?

    travel 1.minute do
      @product.update!(list_price: 100)
      assert @product.review_stale?
    end
  end

  test "requiere comentario si pide cambios" do
    post reviews_url, params: {reviewable_type: "Product", reviewable_id: @product.id, status: "needs_changes", note: ""}
    assert_equal "pending", @product.reload.review_status
  end

  test "solo modelos revisables" do
    post reviews_url, params: {reviewable_type: "User", reviewable_id: 1, status: "approved"}
    assert_response :bad_request
  end

  test "revisor edita el catálogo y descarga CSV pero no administra usuarios" do
    get products_url
    assert_response :success
    get odoo_export_url("4_product_template.csv")
    assert_response :success
    get users_url
    assert_redirected_to root_path
  end

  test "aprobar y siguiente salta al próximo pendiente" do
    post reviews_url(advance: 1), params: {reviewable_type: "Product", reviewable_id: @product.id, status: "approved"}
    nxt = Product.review_is("pending").order(:name, :id).first
    assert_redirected_to product_path(nxt)
    assert_not_equal @product.id, nxt.id
  end
end
