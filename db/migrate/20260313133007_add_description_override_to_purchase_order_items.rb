class AddDescriptionOverrideToPurchaseOrderItems < ActiveRecord::Migration[7.2]
  def change
    add_column :purchase_order_items, :description_override, :string
  end
end
