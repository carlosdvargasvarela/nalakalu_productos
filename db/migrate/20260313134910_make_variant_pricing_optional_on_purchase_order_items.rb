class MakeVariantPricingOptionalOnPurchaseOrderItems < ActiveRecord::Migration[7.2]
  def change
    change_column_null :purchase_order_items, :variant_pricing_id, true
  end
end
