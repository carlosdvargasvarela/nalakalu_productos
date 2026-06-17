class InventoryBulkImportService
  REQUIRED_HEADERS = %w[
    sala_receptora_entradas sala_emisora_salidas codigo_producto nombre_de_producto cantidad
  ].freeze

  Result = Struct.new(:sync, :file_errors, keyword_init: true)

  PendingMovement = Struct.new(
    :type, :showroom, :product, :product_name_raw, :quantity,
    :order_number, :delivery_date, :line_number, keyword_init: true
  )

  def self.call(file_path)
    new(file_path).import
  end

  def initialize(file_path)
    @file_path = file_path
    @row_errors = []
  end

  def import
    parsed = XlsxImportHelper.read_xlsx(@file_path)
    return failure(parsed[:errors]) if parsed[:errors].any?
    return failure(["El archivo no tiene filas."]) if parsed[:rows].empty?

    validation = CsvImportHelper.validate_headers(parsed[:rows].first.keys, REQUIRED_HEADERS)
    return failure([validation[:message]]) unless validation[:valid]

    pending = parsed[:rows].each_with_index.flat_map { |row, index| build_pending(row, index + 2) }

    sync = create_sync(pending)
    movements_created = save_movements(sync, pending)
    finalize_sync(sync, rows_count: parsed[:rows].size, created: movements_created)

    Result.new(sync: sync, file_errors: [])
  end

  private

  def failure(errors)
    Result.new(sync: nil, file_errors: errors)
  end

  def build_pending(row, line_number)
    code     = CsvImportHelper.normalize_string(row["codigo_producto"])
    name     = CsvImportHelper.normalize_string(row["nombre_de_producto"])
    quantity = CsvImportHelper.to_decimal(row["cantidad"])
    source_name      = CsvImportHelper.normalize_string(row["sala_emisora_salidas"])
    destination_name = CsvImportHelper.normalize_string(row["sala_receptora_entradas"])
    order_number     = CsvImportHelper.normalize_string(row["pedido"])
    delivery_date    = parse_date(row["fecha_del_movimiento"])

    if source_name.blank? && destination_name.blank?
      @row_errors << "Fila #{line_number}: debes indicar al menos una sala (receptora o emisora)."
      return []
    end

    if quantity.nil? || quantity <= 0
      @row_errors << "Fila #{line_number}: cantidad inválida."
      return []
    end

    if code.blank? && name.blank?
      @row_errors << "Fila #{line_number}: debes indicar código o nombre de producto."
      return []
    end

    source      = find_showroom(source_name)
    destination = find_showroom(destination_name)

    if source_name.present? && source.nil?
      @row_errors << "Fila #{line_number}: sala emisora '#{source_name}' no encontrada."
      return []
    end
    if destination_name.present? && destination.nil?
      @row_errors << "Fila #{line_number}: sala receptora '#{destination_name}' no encontrada."
      return []
    end

    product  = resolve_product(code, name)
    raw_name = name.presence || code

    entries = []
    entries << PendingMovement.new(type: "exit", showroom: source, product: product,
      product_name_raw: raw_name, quantity: quantity, order_number: order_number,
      delivery_date: delivery_date, line_number: line_number) if source
    entries << PendingMovement.new(type: "entry", showroom: destination, product: product,
      product_name_raw: raw_name, quantity: quantity, order_number: order_number,
      delivery_date: delivery_date, line_number: line_number) if destination
    entries
  end

  def find_showroom(identifier)
    return nil if identifier.blank?
    showrooms_by_identifier[identifier.downcase]
  end

  def showrooms_by_identifier
    @showrooms_by_identifier ||= Showroom.active.each_with_object({}) do |s, h|
      h[s.code.downcase] = s
      h[s.name.downcase] = s
    end
  end

  def resolve_product(code, name)
    if code.present?
      Product.find_by("LOWER(base_code) = ?", code.downcase)
    elsif name.present?
      Product.find_by("LOWER(name) = ?", name.downcase)
    end
  end

  def parse_date(value)
    return nil if value.blank?
    Date.parse(value)
  rescue ArgumentError, TypeError
    nil
  end

  def create_sync(pending)
    dates = pending.map(&:delivery_date).compact
    InventorySync.create!(
      kind: "bulk_upload",
      from_date: dates.min || Date.current,
      to_date:   dates.max || Date.current,
      status:    "pending_review",
      synced_at: Time.current
    )
  end

  def save_movements(sync, pending)
    pending.filter_map do |entry|
      movement = InventoryMovement.new(
        inventory_sync:    sync,
        movement_type:      entry.type,
        showroom:           entry.showroom,
        product:            entry.product,
        product_name_raw:   entry.product_name_raw,
        quantity:           entry.quantity,
        order_number:       entry.order_number.presence || "CARGA-#{sync.id}-F#{entry.line_number}",
        delivery_date:      entry.delivery_date || Date.current,
        source:             "manual",
        status:             entry.product ? "resolved" : "unresolved"
      )

      if movement.save
        movement
      else
        @row_errors << "Fila #{entry.line_number}: #{movement.errors.full_messages.join(', ')}"
        nil
      end
    end
  end

  def finalize_sync(sync, rows_count:, created:)
    sync.update!(
      deliveries_processed: rows_count,
      movements_count:      created.size,
      unresolved_count:     created.count { |m| m.status == "unresolved" },
      import_errors:        @row_errors
    )
  end
end
