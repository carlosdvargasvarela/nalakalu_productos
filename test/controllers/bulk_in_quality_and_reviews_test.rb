require "test_helper"

class BulkInQualityAndReviewsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:revisor)
    Product.destroy_all
    @a = Product.create!(name: "Sin precio A", base_code: "A1")
    @b = Product.create!(name: "Sin precio B", base_code: "B1")
  end

  test "calidad: las comprobaciones de registros tienen casillas y barra con todos los ids" do
    get quality_url(check: "products_no_price")
    assert_response :success
    assert_select "input[type=checkbox][name='ids[]'][form=bulk-form]", count: 2
    assert_select "button[name=bulk_action][value=assign_family]"
    ids = JSON.parse(css_select("[data-bulk-actions-all-ids-value]").first["data-bulk-actions-all-ids-value"])
    assert_equal [@a.id, @b.id].sort, ids.sort
    assert_equal quality_path(check: "products_no_price"), css_select("input[name=return_to]").first["value"]
  end

  test "calidad: la comprobación de reglas (no son registros) no ofrece selección" do
    tipo = VariantType.create!(name: "T")
    ProductVariantRule.create!(product: @a, variant_type: tipo, position: 1)
    Compatibility.where(compatible_type: "ProductVariantRule").delete_all
    get quality_url(check: "rules_no_variants")
    assert_response :success
    assert_select "input[name='ids[]']", count: 0
    assert_select "#bulk-form", count: 0
  end

  test "calidad: ocultar en masa desde la lista vuelve a la misma comprobación" do
    post bulk_url("product"), params: {ids: [@a.id, @b.id], bulk_action: "hide", return_to: quality_path(check: "products_no_price")}
    assert_redirected_to quality_path(check: "products_no_price")
    assert_equal [false, false], [@a, @b].map { _1.reload.active }
    get quality_url(check: "products_no_price") # los ocultos ya no son «activos sin precio»
    assert_select "input[name='ids[]']", count: 0
  end

  test "por corregir: con un tipo elegido hay selección y aprobar en masa los saca de la lista y limpia la nota" do
    [@a, @b].each { |p| Review.create!(reviewable: p, status: "needs_changes", note: "Falta precio") }
    get reviews_url
    assert_match "elige arriba un tipo", response.body
    assert_select "input[name='ids[]']", count: 0

    get reviews_url(type: "Product")
    assert_select "input[type=checkbox][name='ids[]'][form=bulk-form]", count: 2
    assert_equal [@a.id, @b.id].sort, JSON.parse(css_select("[data-bulk-actions-all-ids-value]").first["data-bulk-actions-all-ids-value"]).sort

    post bulk_url("product"), params: {ids: [@a.id, @b.id], bulk_action: "approve", return_to: reviews_path(type: "Product")}
    assert_redirected_to reviews_path(type: "Product")
    assert_equal ["approved"] * 2, [@a, @b].map { _1.reload.review_status }
    assert_nil @a.review.note
    get reviews_url(type: "Product")
    assert_match "No hay nada por corregir", response.body
  end

  test "por corregir: volver a pendiente y eliminar en masa" do
    Review.create!(reviewable: @a, status: "needs_changes", note: "x")
    Review.create!(reviewable: @b, status: "needs_changes", note: "y")
    post bulk_url("product"), params: {ids: [@a.id], bulk_action: "pending"}
    assert_equal "pending", @a.reload.review_status
    post bulk_url("product"), params: {ids: [@b.id], bulk_action: "delete", confirmed: "1", return_to: reviews_path(type: "Product")}
    assert_not Product.exists?(@b.id)
    assert_equal 0, Review.where(reviewable_type: "Product", reviewable_id: @b.id).count
  end
end
