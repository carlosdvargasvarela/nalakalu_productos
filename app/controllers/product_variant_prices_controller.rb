# app/controllers/product_variant_prices_controller.rb
class ProductVariantPricesController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!

  def create
    product = Product.find(params[:product_id])
    prices_params = params[:prices] || {}

    ProductVariantPrice.transaction do
      prices_params.each do |variant_id, price_value|
        # Buscamos o inicializamos el registro de precio
        pvp = ProductVariantPrice.find_or_initialize_by(
          product_id: product.id,
          variant_id: variant_id
        )

        if price_value.present?
          pvp.price = price_value
          pvp.save!
        elsif pvp.persisted?
          # Si el campo está vacío, eliminamos el precio específico
          pvp.destroy
        end
      end
    end

    redirect_to product_path(product, anchor: "variant-prices"),
      notice: "Precios actualizados correctamente para #{product.name}."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to product, alert: "Error al actualizar precios: #{e.message}"
  end
end
