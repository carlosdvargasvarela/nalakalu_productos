require "test_helper"

class SupplierItemsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:revisor)
    @item = SupplierItem.create!(provider: providers(:one), name: "Sobre", sku: "S-1", default_cost: 100)
    @item.supplier_links.create!(product: products(:one))
    @variants = [variants(:one), variants(:two)]
  end

  test "duplica la pieza por variante, vinculada al mismo producto y sin código" do
    assert_difference("SupplierItem.count", 2) do
      post duplicate_supplier_item_url(@item), params: {variant_ids: ["", *@variants.map(&:id)]}
    end
    copy = SupplierLink.find_by!(variant: @variants.first).supplier_item
    assert_equal "Sobre · #{@variants.first.seller_name}", copy.name
    assert_nil copy.sku
    assert_equal 100, copy.default_cost
    assert_equal [[products(:one).id, @variants.first.id]], copy.supplier_links.pluck(:product_id, :variant_id)
  end

  test "sin variantes no crea nada" do
    assert_no_difference("SupplierItem.count") { post duplicate_supplier_item_url(@item), params: {variant_ids: [""]} }
  end

  test "la pantalla de la pieza carga" do
    get supplier_item_url(@item)
    assert_response :success
  end
end
