# Acciones sobre varios registros a la vez desde las listas. Cada petición es un solo lote del Historial (deshacible).
class BulkActionsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_catalog_editor!
  before_action :load_records

  class Refused < StandardError; end # se muestra tal cual como aviso

  KINDS = DeletionsController::KINDS
  ACTIONS = %w[approve pending needs_changes hide show delete merge assign_family unassign_family move_type move_provider].freeze
  MERGEABLE = %w[family variant_type provider].freeze

  def confirm_delete_page
    @impact = Hash.new(0)
    @records.first(2000).each { |r| DeleteImpact.for(r).each { |text, n, loses| @impact[[text, loses]] += n } }
    @sample = @records.first(12)
    render :confirm_delete
  end

  # unir sin confirmar: elegir cuál se conserva y ver qué pasa
  def confirm_merge_page
    raise Refused, "Unir solo aplica a familias, tipos de variante y proveedores." unless MERGEABLE.include?(@kind)
    raise Refused, "Elige al menos 2 para unirlos." if @records.size < 2

    @stats = @records.index_with { |r| merge_stats(r) }
    @default_target = @records.max_by { |r| @stats[r][:main] }
    @warnings = merge_warnings
    render :confirm_merge
  rescue Refused => e
    back(alert: e.message)
  end

  # delete sin confirmar muestra el impacto total y ofrece ocultar en su lugar (confirm_delete_page)
  def create
    action = params[:bulk_action].to_s
    return back(alert: "Acción no válida.") unless ACTIONS.include?(action)
    return back(alert: "No elegiste ningún registro.") if @records.empty?

    return confirm_delete_page if action == "delete" && params[:confirmed] != "1"
    return confirm_merge_page if action == "merge" && params[:confirmed] != "1"

    message = ActiveRecord::Base.transaction { send("do_#{action}") } # todo o nada
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
      review.note = note # approve/pending: se limpia; needs_changes: el comentario nuevo
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

  # ── Unir ───────────────────────────────────────────────────────────────
  def do_merge
    raise Refused, "Unir solo aplica a familias, tipos de variante y proveedores." unless MERGEABLE.include?(@kind)

    target = @records.find { _1.id == params[:target_id].to_i } or raise Refused, "Elige cuál se conserva."
    sources = @records - [target]
    raise Refused, "Elige al menos 2 para unirlos." if sources.empty?

    new_name = params[:new_name].to_s.strip
    case target
    when Family then merge_families(target, sources)
    when VariantType then sources.each { _1.merge_into!(target) }
    when Provider then merge_providers(target, sources)
    end
    sources.each { _1.update!(active: false) unless _1.is_a?(VariantType) } # merge_into! ya oculta los tipos
    target.update!(name: new_name) if new_name.present? && new_name != target.name
    "Se unieron #{sources.size + 1} #{@model.model_name.human(count: 2).downcase} en «#{target.reload.name}». #{n_(sources.size, "quedó oculto", "quedaron ocultos")}: #{sources.map(&:name).to_sentence}."
  end

  def merge_families(target, sources)
    sources.each do |src|
      ChangeLog.bulk_update(Product.where(family_id: src.id), family_id: target.id) # solo agrupa: los productos conservan sus reglas
      # los tipos de variante que le faltan al destino se agregan SIN propagarlos a sus productos (el callback los llenaría de variantes)
      have = target.family_variant_rules.map { [_1.variant_type_id, _1.label] }
      pos = target.family_variant_rules.maximum(:position).to_i
      src.family_variant_rules.order(:position).each do |fr|
        next if have.include?([fr.variant_type_id, fr.label])

        pos += 1
        now = Time.current
        id = FamilyVariantRule.insert_all([{family_id: target.id, variant_type_id: fr.variant_type_id, position: pos, required: fr.required,
          separator: fr.separator, label: fr.label, created_at: now, updated_at: now}], returning: %w[id]).rows.first.first
        rule = FamilyVariantRule.find(id)
        ChangeLog.log(rule, "create", nil, rule.attributes)
        have << [fr.variant_type_id, fr.label]
      end
    end
  end

  def merge_providers(target, sources)
    sources.each { |src| ChangeLog.bulk_update(SupplierItem.where(provider_id: src.id), provider_id: target.id) }
  rescue ActiveRecord::RecordNotUnique
    raise Refused, "No se pudo unir: hay piezas con el mismo código en más de un proveedor. Resuélvelo primero (elimina o cambia el código de una)."
  end

  def merge_stats(r)
    case r
    when Family then {main: r.products.count, text: "#{n_(r.products.count, "producto")} · #{n_(r.family_variant_rules.count, "tipo de variante", "tipos de variante")}"}
    when VariantType then {main: r.variants.count, text: "#{n_(r.variants.count, "variante")} · #{n_(r.product_variant_rules.count, "producto lo usa", "productos lo usan")}"}
    when Provider then {main: r.supplier_items.count, text: n_(r.supplier_items.count, "pieza")}
    end
  end

  def merge_warnings
    w = []
    types = @records.select { _1.is_a?(VariantType) }
    if types.size > 1
      names = Variant.where(variant_type_id: types.map(&:id)).map { _1.seller_name.to_s.squish.downcase }
      dup = names.tally.count { _2 > 1 }
      w << "#{n_(dup, "variante tiene", "variantes tienen")} el mismo nombre en más de un tipo: quedarán repetidas dentro del tipo unido (Calidad las lista para corregirlas)." if dup > 0
      w << "Los tipos no coinciden en «código de proveedor propio»: se conserva el del tipo que elijas." if types.map(&:own_supplier_code).uniq.size > 1
    end
    w
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
