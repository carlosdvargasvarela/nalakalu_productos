# Edición de un solo campo desde las listas (ver quick_edit_controller.js).
class QuickEditsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_catalog_editor!

  FIELDS = {
    "product" => [Product, %w[name base_code list_price]],
    "variant" => [Variant, %w[name display_name code]],
    "supplier_item" => [SupplierItem, %w[name sku default_cost]],
    "provider" => [Provider, %w[name email phone]],
    "family" => [Family, %w[name]],
    "variant_type" => [VariantType, %w[name]]
  }.freeze

  def update
    model, fields = FIELDS.fetch(params[:kind])
    return head :unprocessable_entity unless fields.include?(params[:field])

    record = model.find(params[:id])
    if record.update(params[:field] => params[:value].to_s.strip.presence)
      render json: {ok: true}
    else
      render json: {ok: false, error: record.errors.full_messages.to_sentence}, status: :unprocessable_entity
    end
  end
end
