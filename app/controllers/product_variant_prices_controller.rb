class ProductVariantPricesController < ApplicationController
  def create
    @product = Product.find(params[:product_id])
    prices_param = params[:prices] || {}

    ActiveRecord::Base.transaction do
      prices_param.each do |variant_id, price_value|
        record = @product.product_variant_prices.find_or_initialize_by(variant_id: variant_id)
        if price_value.present?
          record.price = price_value
          record.save!
        elsif record.persisted?
          record.destroy
        end
      end
    end

    redirect_to @product, notice: "Precios actualizados correctamente."
  end
end
