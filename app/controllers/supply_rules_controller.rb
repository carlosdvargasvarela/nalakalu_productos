class SupplyRulesController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!
  before_action :set_supply_rule, only: %i[edit update destroy]

  def index
    @supply_rules = SupplyRule.ordered
  end

  def new
    @supply_rule = SupplyRule.new
    @products = Product.where(active: true).order(:name)
    @variant_types = VariantType.where(active: true).order(:name)
    @supplier_items = SupplierItem.active.includes(:provider).order("providers.name, supplier_items.name")
  end

  def create
    @supply_rule = SupplyRule.new(supply_rule_params)
    if @supply_rule.save
      redirect_to supply_rules_path, notice: "Regla creada correctamente."
    else
      @products = Product.where(active: true).order(:name)
      @variant_types = VariantType.where(active: true).order(:name)
      @supplier_items = SupplierItem.active.includes(:provider).order("providers.name, supplier_items.name")
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @products = Product.where(active: true).order(:name)
    @variant_types = VariantType.where(active: true).order(:name)
    @supplier_items = SupplierItem.active.includes(:provider).order("providers.name, supplier_items.name")
  end

  def update
    if @supply_rule.update(supply_rule_params)
      redirect_to supply_rules_path, notice: "Regla actualizada."
    else
      @products = Product.where(active: true).order(:name)
      @variant_types = VariantType.where(active: true).order(:name)
      @supplier_items = SupplierItem.active.includes(:provider).order("providers.name, supplier_items.name")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @supply_rule.destroy
    redirect_to supply_rules_path, notice: "Regla eliminada."
  end

  # Vista para configurar reglas de un producto específico de forma masiva
  def bulk_new
    @products = Product.where(active: true).order(:name)
    @supplier_items = SupplierItem.active.includes(:provider).order("providers.name, supplier_items.name")

    if params[:product_id].present?
      @product = Product.find(params[:product_id])
      @variant_types = @product.variant_types.includes(:variants).order(:name)
      @existing_rules = SupplyRule.where(product: @product).index_by { |r| "#{r.variant_type_id}_#{r.variant_id}" }
    end
  end

  def bulk_create
    product = Product.find(params[:product_id])
    rules_params = params[:rules] || {}
    errors = []

    ActiveRecord::Base.transaction do
      rules_params.each do |key, data|
        variant_type_id, variant_id = key.split("_").map { |x| x.presence&.to_i }

        if data[:supplier_item_id].blank?
          # Si limpiaron el select, eliminamos la regla si existía
          SupplyRule.find_by(
            product: product,
            variant_type_id: variant_type_id,
            variant_id: variant_id
          )&.destroy
          next
        end

        rule = SupplyRule.find_or_initialize_by(
          product: product,
          variant_type_id: variant_type_id,
          variant_id: variant_id.presence
        )

        rule.assign_attributes(
          supplier_item_id: data[:supplier_item_id],
          quantity_needed: data[:quantity_needed].presence || 1.0,
          rule_type: data[:rule_type].presence || "individual"
        )

        errors << rule.errors.full_messages unless rule.save
      end

      raise ActiveRecord::Rollback if errors.any?
    end

    if errors.any?
      redirect_to bulk_new_supply_rules_path(product_id: product.id),
        alert: "Errores al guardar: #{errors.flatten.first(3).join(" | ")}"
    else
      redirect_to bulk_new_supply_rules_path(product_id: product.id),
        notice: "Reglas de '#{product.name}' guardadas correctamente."
    end
  end

  private

  def set_supply_rule
    @supply_rule = SupplyRule.find(params[:id])
  end

  def supply_rule_params
    params.require(:supply_rule).permit(
      :product_id, :variant_type_id, :variant_id,
      :supplier_item_id, :quantity_needed, :rule_type
    )
  end
end
