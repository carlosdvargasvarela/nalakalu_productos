class SupplyRulesController < ApplicationController
  before_action :set_supply_rule, only: %i[edit update destroy]

  def index
    @supply_rules = SupplyRule.includes(:product, :variant, :supplier_item)
      .order("products.name, variants.name")
  end

  def new
    @supply_rule = SupplyRule.new
  end

  def create
    @supply_rule = SupplyRule.new(supply_rule_params)
    if @supply_rule.save
      redirect_to supply_rules_path, notice: "Regla creada correctamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @supply_rule.update(supply_rule_params)
      redirect_to supply_rules_path, notice: "Regla actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @supply_rule.destroy
    redirect_to supply_rules_path, notice: "Regla eliminada."
  end

  def bulk_new
    @products = Product.order(:name)
    @supplier_items = SupplierItem.includes(:provider).order(:name)

    if params[:product_id].present?
      @product = Product.find(params[:product_id])
      @variants = @product.variants.includes(:variant_type).order("variant_types.name, variants.name")
      @existing_rules = SupplyRule.where(product: @product).index_by(&:variant_id)
    end
  end

  def bulk_create
    rules_params = params[:rules] || {}
    product = Product.find(params[:product_id])

    rules_params.each do |variant_id, data|
      if data[:supplier_item_id].blank?
        # Si limpiaron el select, eliminamos la regla si existía
        SupplyRule.find_by(product: product, variant_id: variant_id)&.destroy
        next
      end

      rule = SupplyRule.find_or_initialize_by(product: product, variant_id: variant_id)
      rule.update(
        supplier_item_id: data[:supplier_item_id],
        quantity: data[:quantity].presence || 1
      )
    end

    redirect_to bulk_new_supply_rules_path(product_id: product.id),
      notice: "Reglas de '#{product.name}' guardadas correctamente."
  end

  private

  def set_supply_rule
    @supply_rule = SupplyRule.find(params[:id])
  end

  def supply_rule_params
    params.require(:supply_rule).permit(:product_id, :variant_id, :supplier_item_id, :quantity)
  end
end
