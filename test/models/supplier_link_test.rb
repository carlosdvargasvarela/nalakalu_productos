require "test_helper"

class SupplierLinkTest < ActiveSupport::TestCase
  setup do
    @item = SupplierItem.create!(provider: providers(:one), name: "Pieza")
    @product = products(:one)
    @variant = variants(:one)
  end

  test "distingue solo variante, producto + variante y solo producto" do
    assert_equal :variant, SupplierLink.create!(supplier_item: @item, variant: @variant).kind
    assert_equal :product_variant, SupplierLink.create!(supplier_item: @item, product: @product, variant: @variant).kind
    assert_equal :product, SupplierLink.create!(supplier_item: @item, product: @product).kind
  end

  test "exige producto o variante y no repite" do
    assert_not SupplierLink.new(supplier_item: @item).valid?
    SupplierLink.create!(supplier_item: @item, variant: @variant)
    assert_not SupplierLink.new(supplier_item: @item, variant: @variant).valid?
  end
end
