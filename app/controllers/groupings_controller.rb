# Reorganizar: mover hijos (productos / variantes / piezas) de un grupo a uno nuevo (= duplicar el grupo
# sin duplicar lo de adentro), a uno existente, o (familias) a ninguno.
class GroupingsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_catalog_editor!
  before_action :load_group

  Kind = Struct.new(:model, :children, :noun, :child_noun, :title, :sub)
  KINDS = {
    "family" => Kind.new(Family, :products, "familia", "productos", ->(c) { c.name }, ->(c) { c.base_code }),
    "variant_type" => Kind.new(VariantType, :variants, "tipo de variante", "variantes", ->(c) { c.seller_name }, ->(c) { c.code }),
    "provider" => Kind.new(Provider, :supplier_items, "proveedor", "piezas", ->(c) { c.name }, ->(c) { c.sku })
  }.freeze

  def new
    @children = @group.public_send(@kind.children).order(:name)
    @others = @kind.model.where.not(id: @group.id).order(:name)
  end

  def create
    ids = Array(params[:child_ids]).compact_blank.map(&:to_i)
    target = nil
    ActiveRecord::Base.transaction do
      target = (params[:dest] == "new") ? build_new : (params[:dest] == "existing" ? @kind.model.find(params[:target_id]) : nil)
      move(ids, target)
    end
    @group.update!(active: false) if params[:hide_source] == "1" && target && target.id != @group.id
    redirect_to polymorphic_path(target || @group), notice: "Listo: #{ids.size} #{@kind.child_noun} #{target ? "movidos a «#{target.name}»" : "sin #{@kind.noun}"}."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ActiveRecord::RecordNotFound => e
    redirect_to reorganize_path(params[:kind], @group), alert: "No se pudo: #{e.message}"
  end

  private

  def load_group
    @kind = KINDS.fetch(params[:kind])
    @group = @kind.model.find(params[:id])
  end

  def build_new
    case @group
    when Family
      g = Family.create!(name: params[:new_name], description: @group.description, active: @group.active)
      @group.family_variant_rules.each { g.family_variant_rules.create!(_1.attributes.slice("variant_type_id", "position", "required", "separator", "label")) }
      g
    when VariantType
      VariantType.create!(@group.attributes.slice("description", "procurement_strategy", "keep_position", "own_supplier_code", "active").merge("name" => params[:new_name]))
    when Provider
      Provider.create!(@group.attributes.slice("category", "contact_name", "email", "phone", "notes", "active").merge("name" => params[:new_name]))
    end
  end

  def move(ids, target)
    case @group
    when Family
      if target && params[:apply_rules] == "1"
        Product.where(id: ids, family_id: @group.id).each { _1.update!(family_id: target.id) } # clona las reglas de la familia destino
      else
        ChangeLog.bulk_update(Product.where(id: ids, family_id: @group.id), family_id: target&.id) # solo agrupa, conserva sus reglas
      end
    when VariantType
      raise ActiveRecord::RecordNotFound, "elige un destino" unless target
      @group.move_variants_to!(target, ids, carry_to_products: params[:dest] == "new" && params[:carry_to_products] == "1")
    when Provider
      raise ActiveRecord::RecordNotFound, "elige un destino" unless target
      ChangeLog.bulk_update(SupplierItem.where(id: ids, provider_id: @group.id), provider_id: target.id)
    end
  end
end
