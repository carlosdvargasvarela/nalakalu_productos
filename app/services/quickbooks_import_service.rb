# Carga el export de QuickBooks (ya convertido a filas) y concilia el catálogo contra él:
#  - guarda todas las filas en qb_items (consulta)
#  - productos con el mismo código: toma el precio de QuickBooks
#  - productos sin ese código: los marca «requiere cambios» con una nota (no se modifica nada más)
#  - ítems de compra: se crean como piezas de proveedor pendientes de revisión (origen quickbooks)
# Es idempotente: se puede correr más de una vez. Todo queda en un lote del Historial (deshacible).
class QuickbooksImportService
  NO_VENDOR = "Sin proveedor (QuickBooks)".freeze
  UNITS = {"meter" => "metro", "lamina" => "lámina", "pieza" => "pieza", "pulgada" => "pulgada", "gallon" => "galón"}.freeze

  # rows: [{"item"=>, "desc"=>, "type"=>, "cost"=>, "price"=>, "um"=>, "vendor"=>}]
  # vendor_map: {"nombre en QuickBooks" => "nombre en Odoo"} (sin entrada = no encontrado en Odoo)
  def initialize(rows, vendor_map = {})
    @rows = rows
    @vendor_map = vendor_map
    @stats = Hash.new(0)
  end

  def run
    Current.batch_id ||= SecureRandom.uuid
    load_items
    reconcile_products
    import_supplier_items
    @stats
  end

  private

  def load_items
    now = Time.current
    records = @rows.filter_map do |r|
      code = r["item"].to_s.strip
      next if code.empty?

      {code: code, description: QbItem.clean_name(r["desc"]), raw_description: r["desc"].to_s, item_type: r["type"].to_s,
       cost: decimal(r["cost"]), price: decimal(r["price"]), vendor: r["vendor"].to_s.strip.presence, unit: r["um"].to_s.strip.presence,
       created_at: now, updated_at: now}
    end
    QbItem.upsert_all(records, unique_by: :code) if records.any?
    @stats[:qb_items] = records.size
  end

  # ── Productos ──────────────────────────────────────────────────────────
  def reconcile_products
    qb = QbItem.all.index_by(&:code)
    by_name = qb.values.group_by { norm(_1.description) }
    Product.find_each do |p|
      item = qb[p.base_code]
      if item
        @stats[:products_found] += 1
        if item.price.to_f.positive?
          if p.list_price != item.price
            p.update!(list_price: item.price)
            @stats[:prices_set] += 1
          end
        else
          flag(p, "QuickBooks tiene este código pero sin precio.", :products_flagged)
        end
      else
        flag(p, missing_note(p, qb, by_name), :products_flagged)
      end
    end
  end

  def missing_note(p, qb, by_name)
    inactive = p.active ? "" : " (está inactivo)"
    unless p.base_code.to_s.match?(/\A\d{9}\z/)
      return "El código «#{p.base_code}» no tiene el formato de QuickBooks (9 dígitos) y no existe allá.#{inactive}"
    end

    same_name = by_name[norm(p.name)]&.first
    return "QuickBooks lo tiene con otro código: #{same_name.code} («#{same_name.description}»). Revisa si hay que cambiar el código.#{inactive}" if same_name

    like = qb.values.find { _1.code.start_with?(p.base_code[0, 6]) && norm(_1.description).split.first(3) == norm(p.name).split.first(3) }
    return "No existe en QuickBooks con este código. Hay uno parecido: #{like.code} («#{like.description}»).#{inactive}" if like

    "No existe en QuickBooks con este código.#{inactive}"
  end

  # ── Piezas de compra ───────────────────────────────────────────────────
  def import_supplier_items
    product_codes = Product.pluck(:base_code).to_set
    existing = SupplierItem.where.not(sku: nil).pluck(:sku).to_set
    providers = {}
    @rows.each do |r|
      code = r["item"].to_s.strip
      next unless r["type"] == "Inventory Part" && code.match?(/\A[A-Za-z]{3}/) && !product_codes.include?(code)
      next @stats[:items_skipped_existing] += 1 if existing.include?(code)

      vendor = r["vendor"].to_s.strip
      odoo_name = vendor.empty? ? nil : @vendor_map[vendor]
      provider_name = vendor.empty? ? NO_VENDOR : (odoo_name.presence || vendor.delete("*").squish)
      provider = (providers[provider_name] ||= find_or_create_provider(provider_name, vendor.empty?))

      name = QbItem.clean_name(r["desc"])
      cost = decimal(r["cost"])
      item = SupplierItem.create!(provider: provider, name: name.presence || code, sku: code, unit: unit(r["um"]),
        default_cost: cost&.positive? ? cost : nil, active: true, source: "quickbooks")
      @stats[:items_created] += 1

      problems = []
      problems << "QuickBooks no tiene proveedor para esta pieza." if vendor.empty?
      problems << "El proveedor «#{vendor}» no se encontró en los contactos de Odoo." if vendor.present? && odoo_name.blank?
      problems << "Sin costo en QuickBooks." unless cost&.positive?
      problems << "Sin descripción en QuickBooks." if name.empty?
      flag(item, problems.join(" "), :items_flagged) if problems.any?
    end
    @stats[:providers_created] = providers.values.count { _1.previously_new_record? }
  end

  def find_or_create_provider(name, none)
    Provider.find_by(name: name) || Provider.create!(name: name, category: "externo", active: !none,
      notes: none ? "Marcador para piezas que QuickBooks no asigna a ningún proveedor." : "Creado desde QuickBooks.")
  end

  # ── Utilidades ─────────────────────────────────────────────────────────
  # No pisa una revisión hecha por una persona.
  def flag(record, note, counter)
    review = record.review || record.build_review
    return if review.persisted? && review.status != "pending" && review.user_id.present?
    return if review.persisted? && review.status == "needs_changes" && review.note == note

    was_new = review.new_record?
    before = review.attributes.slice("status", "note", "user_id")
    review.assign_attributes(status: "needs_changes", note: note, user: nil)
    review.save!
    # Review no es Tracked (las revisiones humanas no se deshacen en lote); las automáticas sí, para que el lote deshaga todo junto.
    was_new ? ChangeLog.log(review, "create", nil, review.attributes) : ChangeLog.log(review, "update", before, review.attributes.slice("status", "note", "user_id"))
    @stats[counter] += 1
  end

  def unit(raw)
    base = I18n.transliterate(raw.to_s.sub(/\s*\(.*\)/, "").strip.downcase)
    return "unidad" if base.empty?

    UNITS.fetch(base) { (base == "unidad" || base == "par") ? base : raw.to_s.sub(/\s*\(.*\)/, "").strip.downcase }
  end

  def decimal(v)
    return nil if v.to_s.strip.empty?
    BigDecimal(v.to_s)
  rescue ArgumentError
    nil
  end

  def norm(text)
    I18n.transliterate(QbItem.clean_name(text)).downcase.sub(/\.+\z/, "").gsub(/[^a-z0-9]+/, " ").squish
  end
end
