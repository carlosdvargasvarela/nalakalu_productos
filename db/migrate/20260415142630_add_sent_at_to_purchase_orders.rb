class AddSentAtToPurchaseOrders < ActiveRecord::Migration[7.2]
  def change
    add_column :purchase_orders, :sent_at, :datetime
  end
end
