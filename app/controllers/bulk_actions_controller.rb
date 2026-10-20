# Acciones sobre varios registros a la vez desde las listas. Cada petición es un solo lote del Historial (deshacible).
class BulkActionsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_catalog_editor!
  before_action :load_records

  class Refused < StandardError; end # se muestra tal cual como aviso

  KINDS = DeletionsController::KINDS
  ACTIONS = %w[approve pending needs_changes hide show delete assign_family unassign_family move_type move_provider].freeze

  def confirm_delete_page
    @impact = Hash.new(0)
    @records.first(2000).each { |r| DeleteImpact.for(r).each { |text, n, loses| @impact[[text, loses]] += n } }
    @sample = @records.first(12)
    render :confirm_delete
  end

  # delete sin confirmar muestra el impacto total y ofrece ocultar en su lugar (confirm_delete_page)
  def create
    action = params[:bulk_action].to_s
    return back(alert: "Acción no válida.") unless ACTIONS.include?(action)
    return back(alert: "No elegiste ningún registro.") if @records.empty?

    return confirm_delete_page if action == "delete" && params[:confirmed] != "1"

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

  # Vuelve a la lista de origen (con sus filtros). Nunca al Referer: tras la pantalla de confirmación sería una URL que solo acepta POST.
  # "1 aprobado" / "3 aprobados"
  def n_(n, one, many = "#{one}s") = (n == 1) ? "1 #{one}" : "#{n} #{many}"

  def back(**flash)
    redirect_to return_path, status: :see_other, **flash
  end

  def return_path
    to = params[:return_to].to_s
    (to.start_with?("/") && !to.start_with?("//")) ? to : polymorphic_path(@model)
  end
  helper_method :return_path

  # ── Revisión ───────────────────────────────────────────────────────────
  def do_approve = set_review("approved", nil, "aprobado")
  def do_pending = set_review("pending", nil, "marcado como pendiente", "marcados como pendientes")

  def do_needs_changes
    raise Refused, "Escribe un comentario: es obligatorio para pedir cambios." if params[:note].to_s.strip.empty?
    set_review("needs_changes", params[:note].to_s.strip, "marcado «requiere cambios»", "marcados «requiere cambios»")
  end

  def set_review(status, note, one, many = "#{one}s")
    @records.each do |r|
      review = r.review || r.build_review
      before = review.persisted? ? review.attributes.slice("status", "note", "user_id") : nil
      review.assign_attributes(status: status, user: current_user)
      review.note = note if note
      review.save!
      # Review no es Tracked; en lote sí se registra para poder deshacerlo.
      before ? ChangeLog.log(review, "update", before, review.attributes.slice("status", "note", "user_id")) : ChangeLog.log(review, "create", nil, review.attributes)
    end
    "#{n_(@records.size, one, many)}."
  end

  # ── Ocultar / activar ──────────────────────────────────────────────────
  def do_hide = set_active(false, "oculto")
  def do_show = set_active(true, "activado")

  def set_active(value, one)
    @records.each { _1.update!(active: value) }
    "#{n_(@records.size, one)}."
  end

  # ── Eliminar (requiere confirmación previa) ────────────────────────────
  def do_delete
    failed = @records.reject(&:destroy)
    msg = "#{n_(@records.size - failed.size, "eliminado")}."
    msg += " No se pudo eliminar #{n_(failed.size, "registro")} (tiene dependencias que lo impiden)." if failed.any?
    msg
  end

  # ── Productos: familia ─────────────────────────────────────────────────
  def do_assign_family
    family = Family.find(params[:target_id])
    n = ChangeLog.bulk_update(Product.where(id: @records.map(&:id)), family_id: family.id) # solo agrupa: conserva sus reglas
    "#{n_(n, "producto asignado", "productos asignados")} a «#{family.name}»."
  end

  def do_unassign_family
    n = ChangeLog.bulk_update(Product.where(id: @records.map(&:id)), family_id: nil)
    "#{n_(n, "producto")} sin familia."
  end

  # ── Variantes: tipo ────────────────────────────────────────────────────
  def do_move_type
    target = VariantType.find(params[:target_id])
    moved = 0
    @records.group_by(&:variant_type).each do |type, variants|
      moved += type.move_variants_to!(target, variants.map(&:id)) unless type.id == target.id
    end
    "#{n_(moved, "variante movida", "variantes movidas")} a «#{target.name}»."
  end

  # ── Piezas: proveedor ──────────────────────────────────────────────────
  def do_move_provider
    target = Provider.find(params[:target_id])
    n = ChangeLog.bulk_update(SupplierItem.where(id: @records.map(&:id)), provider_id: target.id)
    "#{n_(n, "pieza movida", "piezas movidas")} a «#{target.name}»."
  end
end
