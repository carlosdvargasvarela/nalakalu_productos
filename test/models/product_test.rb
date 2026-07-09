require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "cached_active_ordered refleja altas, bajas y cambios de productos" do
    Rails.cache.clear
    created = Product.create!(name: "Producto Cache", base_code: "PC-CACHE", active: true)
    assert_includes Product.cached_active_ordered.map(&:id), created.id

    created.update!(active: false)
    assert_not_includes Product.cached_active_ordered.map(&:id), created.id

    created.update!(active: true)
    assert_includes Product.cached_active_ordered.map(&:id), created.id

    created.destroy
    assert_not_includes Product.cached_active_ordered.map(&:id), created.id
  end
end
