# Acciones sobre varios registros a la vez desde las listas. Cada petición es un solo lote del Historial (deshacible).
class BulkActionsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_catalog_editor!
  before_action :load_records

  class Refused < StandardError; end # se muestra tal cual como aviso

  KINDS = DeletionsController::KINDS
  ACTIONS = %w[approve pending needs_changes hide show delete assign_family unassign_family move_type move_provider].freeze

  # Paso previo a eliminar: muestra el impacto total y ofrece ocultar en su lugar.
  def confirm_delete
    @impact = Hash.new(0)
    @records.first(2000).each { |r| DeleteImpact.for(r).each { |text, n, loses| @impact[[text, loses]] += n } }
    @sample = @records.first(12)
  end

  def create
    action = params[:bulk_action].to_s
    return back(alert: "Acción no válida.") unless ACTIONS.include?(action)
    return back(alert: "No elegiste ningún registro.") if @records.empty?

    message = send("do_#{action}")
    back(notice: "#{message} Puedes deshacerlo desde el Historial.")
  rescue Refused => e
    back(alert: e.message)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique, ActiveRecord::RecordNotFound => e
    back(alert: "No se pudo completar: #{e.message}")
  end

  private

  def load_records
    @model = KINDS.fetch(params[:kind])
    @kind = params[:kind]
    ids = (params[:all_mode] == "1") ? params[:all_ids].to_s.split(",") : Array(params[:ids])
    @records = @model.where(id: ids.map(&:to_i).uniq).order(:id).to_a
  end

  def back(**flash)
    redirect_back_or_to polymorphic_path(@model), status: :see_other, **flash
  end

  # ── Revisión ───────────────────────────────────────────────────────────
  def do_approve = set_review("approved", nil, "aprobados")
  def do_pending = set_review("pending", nil, "marcados como pendientes")

  def do_needs_changes
    raise Refused, "Escribe un comentario: es obligatorio para pedir cambios." if params[:note].to_s.strip.empty?
    set_review("needs_changes", params[:note].to_s.strip, "marcados «requiere cambios»")
  end

  def set_review(status, note, label)
    @records.each do |r|
      review = r.review || r.build_review
      before = review.persisted? ? review.attributes.slice("status", "note", "user_id") : nil
      review.assign_attributes(status: status, user: current_user)
      review.note = note if note
      review.save!
      # Review no es Tracked; en lote sí se registra para poder deshacerlo.
      before ? ChangeLog.log(review, "update", before, review.attributes.slice("status", "note", "user_id")) : ChangeLog.log(review, "create", nil, review.attributes)
    end
    "#{@records.size} #{label}."
  end

  # ── Ocultar / activar ──────────────────────────────────────────────────
  def do_hide = set_active(false, "ocultos")
  def do_show = set_active(true, "activados")

  def set_active(value, label)
    @records.each { _1.update!(active: value) }
    "#{@records.size} #{label}."
  end

  # ── Eliminar (requiere confirmación previa) ────────────────────────────
  def do_delete
    raise Refused, "Falta confirmar la eliminación." unless params[:confirmed] == "1"

    failed = @records.reject(&:destroy)
    msg = "#{@records.size - failed.size} eliminados."
    msg += " No se pudieron eliminar #{failed.size} (tienen dependencias que lo impiden)." if failed.any?
    msg
  end

  # ── Productos: familia ─────────────────────────────────────────────────
  def do_assign_family
    family = Family.find(params[:target_id])
    n = ChangeLog.bulk_update(Product.where(id: @records.map(&:id)), family_id: family.id) # solo agrupa: conserva sus reglas
    "#{n} productos asignados a «#{family.name}»."
  end

  def do_unassign_family
    n = ChangeLog.bulk_update(Product.where(id: @records.map(&:id)), family_id: nil)
    "#{n} productos sin familia."
  end

  # ── Variantes: tipo ────────────────────────────────────────────────────
  def do_move_type
    target = VariantType.find(params[:target_id])
    moved = 0
    @records.group_by(&:variant_type).each do |type, variants|
      moved += type.move_variants_to!(target, variants.map(&:id)) unless type.id == target.id
    end
    "#{moved} variantes movidas a «#{target.name}»."
  end

  # ── Piezas: proveedor ──────────────────────────────────────────────────
  def do_move_provider
    target = Provider.find(params[:target_id])
    n = ChangeLog.bulk_update(SupplierItem.where(id: @records.map(&:id)), provider_id: target.id)
    "#{n} piezas movidas a «#{target.name}»."
  end
end
