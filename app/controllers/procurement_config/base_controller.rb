# app/controllers/procurement_config/base_controller.rb
module ProcurementConfig
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_admin!

    private

    def active_products
      Product.where(active: true).order(:name)
    end

    def active_supplier_items
      SupplierItem.active
        .includes(:provider)
        .order("providers.name, supplier_items.name")
    end
  end
end
