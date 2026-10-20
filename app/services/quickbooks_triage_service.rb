# Aplica las decisiones del Excel de triaje (scripts/quickbooks_triage.rb) sobre el catálogo.
# decisions: {
#   "cambiar"  => [{"code"=>"005017000", "new_code"=>"005024300"}],   # cambiar el código al de QuickBooks
#   "ocultar"  => ["005011300", ...],                                  # dejar inactivo
#   "eliminar" => ["Plástico"],
#   "agregar"  => [{"code"=>"001000100", "name"=>"...", "price"=>"129700.0", "family"=>"Mesas de Comedor"}],
#   "revisar"  => [...]                                                # no se toca (solo se cuenta)
# }
# Idempotente. Todo queda en un lote del Historial (deshacible). No pisa revisiones hechas por personas.
class QuickbooksTriageService
  def initialize(decisions)
    @d = decisions
    @stats = Hash.new(0)
    @notes = []
  end

  def run
    Current.batch_id ||= SecureRandom.uuid
    Array(@d["cambiar"]).each { change_code(_1["code"], _1["new_code"]) }
    Array(@d["ocultar"]).each { hide(_1) }
    Array(@d["eliminar"]).each { remove(_1) }
    Array(@d["agregar"]).each { add(_1) }
    @stats[:revisar_pendientes] = Array(@d["revisar"]).size
    [@stats, @notes]
  end

  private

  def change_code(code, new_code)
    product = Product.find_by(base_code: code)
    return skip(:cambiar_ya_aplicado, code) unless product
    return skip(:cambiar_codigo_ocupado, "#{code} → #{new_code}: ya existe un producto con ese código") if Product.exists?(base_code: new_code)

    product.update!(base_code: new_code)
    qb = QbItem.for_code(new_code)
    product.update!(list_price: qb.price) if qb&.price.to_f.positive? && product.list_price != qb.price
    resolve(product, "Triaje: el código se cambió al de QuickBooks (#{code} → #{new_code}).", status: "pending", clear_note: true)
    @stats[:codigos_cambiados] += 1
  end

  def hide(code)
    product = Product.find_by(base_code: code) or return skip(:ocultar_no_encontrado, code)
    if product.active
      product.update!(active: false)
      @stats[:ocultados] += 1
    else
      @stats[:ocultar_ya_inactivos] += 1
    end
    resolve(product, "Triaje: se decidió ocultarlo (inactivo); no existe en QuickBooks.", status: "approved")
  end

  def remove(code)
    product = Product.find_by(base_code: code) or return skip(:eliminar_ya_aplicado, code)
    # Savepoint: si hay datos de módulos ocultos que lo referencian (p. ej. movimientos de inventario, que no se pueden deshacer)
    # no se borra historial: se deja inactivo y se avisa.
    Product.transaction(requires_new: true) { product.destroy! }
    @stats[:eliminados] += 1
  rescue ActiveRecord::InvalidForeignKey
    product.reload.update!(active: false)
    skip(:eliminar_bloqueado, "#{code} («#{product.name}») tiene datos de módulos ocultos (movimientos de inventario…) que no se pueden deshacer; se dejó inactivo en vez de borrarlo")
  end

  def add(row)
    return skip(:agregar_ya_existe, row["code"]) if Product.exists?(base_code: row["code"])

    family = Family.find_by(name: row["family"]) if row["family"].present?
    price = BigDecimal(row["price"].to_s) if row["price"].to_s.strip.present?
    Product.create!(base_code: row["code"], name: QbItem.clean_name(row["name"]), list_price: (price&.positive? ? price : nil), family: family, active: true)
    @stats[:agregados] += 1
  end

  # Cierra la marca automática de la importación (user nil). Una revisión humana no se toca.
  def resolve(product, note, status:, clear_note: false)
    review = product.review
    return unless review && review.status == "needs_changes" && review.user_id.nil?

    before = review.attributes.slice("status", "note", "user_id")
    review.update!(status: status, note: clear_note ? nil : note)
    ChangeLog.log(review, "update", before, review.attributes.slice("status", "note", "user_id"))
    @stats[:marcas_resueltas] += 1
  end

  def skip(key, detail)
    @stats[key] += 1
    @notes << "#{key}: #{detail}"
  end
end
