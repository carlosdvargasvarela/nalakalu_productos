# rails g migration AddOriginProductsToProcurementRequirements
class AddOriginProductsToProcurementRequirements < ActiveRecord::Migration[7.2]
  def change
    add_column :procurement_requirements, :origin_products, :json, default: []
  end
end
