# app/services/import_supplier_items_service.rb
class ImportSupplierItemsService
  include CsvImportHelper

  # Headers requeridos en el CSV
  REQUIRED_HEADERS = ["provider_name", "name"].freeze

  def self.call(file_path)
    new(file_path).import
  end

  def initialize(file_path)
    @file_path = file_path
    @created = 0
    @updated = 0
    @errors = []
    # Contadores para el reporte detallado
    @stats = {
      properties_created: 0,
      property_values_created: 0,
      links_created: 0,
      links_removed: 0
    }
  end

  def import
    result = CsvImportHelper.read_csv(@file_path)

    if result[:errors].any?
      @errors.concat(result[:errors])
      return generate_report(0)
    end

    rows = result[:rows]
    if rows.empty?
      @errors << "El archivo está vacío"
      return generate_report(0)
    end

    validation = CsvImportHelper.validate_headers(rows.first.keys, REQUIRED_HEADERS)
    unless validation[:valid]
      @errors << validation[:message]
      return generate_report(0)
    end

    rows.each_with_index { |row, i| process_row(row, i + 2) }

    generate_report(rows.count)
  end

  private

  def process_row(row, line_number)
    p_name = norm(row["provider_name"])
    name = norm(row["name"])

    if p_name.blank? || name.blank?
      @errors << "Fila #{line_number}: 'provider_name' y 'name' son obligatorios"
      return
    end

    sku = norm(row["sku"])
    unit = norm(row["unit"]).presence || "unidad"
    active = parse_bool(row["active"], default: true)
    cost = parse_number(row["default_cost"])

    # 1. Proveedor (Find or Create)
    provider = Provider.find_or_create_by!(name: p_name)

    # 2. SupplierItem (Unicidad por Provider + SKU + Unit)
    # Si no hay SKU, usamos el nombre como fallback de búsqueda
    item = if sku.present?
      SupplierItem.find_or_initialize_by(provider_id: provider.id, sku: sku, unit: unit)
    else
      SupplierItem.find_or_initialize_by(provider_id: provider.id, name: name, unit: unit)
    end

    is_new = item.new_record?
    item.name = name
    item.sku = sku if sku.present?
    item.active = active
    item.default_cost = cost if row["default_cost"].present?

    if item.save
      is_new ? @created += 1 : @updated += 1
      # 3. Sincronizar Propiedades EAV si la columna existe
      sync_properties!(item, row["properties"]) if row.key?("properties")
    else
      @errors << "Fila #{line_number} (#{name}): #{item.errors.full_messages.join(", ")}"
    end
  rescue => e
    @errors << "Fila #{line_number}: Error inesperado: #{e.message}"
  end

  def sync_properties!(item, raw_props)
    pairs = parse_properties_string(raw_props)
    return if pairs.nil? # Error de formato

    desired_pv_ids = []

    pairs.each do |prop_name, val_text|
      prop = Property.find_or_create_by!(name: prop_name)
      @stats[:properties_created] += 1 if prop.previously_new_record?

      pv = PropertyValue.find_or_create_by!(property_id: prop.id, value: val_text)
      @stats[:property_values_created] += 1 if pv.previously_new_record?

      desired_pv_ids << pv.id
    end

    # Sincronización: borrar lo que no viene, agregar lo nuevo
    existing_links = SupplierItemProperty.where(supplier_item_id: item.id)
    existing_pv_ids = existing_links.pluck(:property_value_id)

    to_add = desired_pv_ids - existing_pv_ids
    to_remove = existing_pv_ids - desired_pv_ids

    @stats[:links_removed] += existing_links.where(property_value_id: to_remove).delete_all if to_remove.any?

    to_add.each do |pv_id|
      SupplierItemProperty.create!(supplier_item_id: item.id, property_value_id: pv_id)
      @stats[:links_created] += 1
    end
  end

  # Helpers de Limpieza
  def norm(val)
    CsvImportHelper.normalize_string(val)
  end

  def parse_bool(val, default:)
    return default if val.nil?
    s = val.to_s.strip.downcase
    return true if %w[true 1 si sí s y yes].include?(s)
    return false if %w[false 0 no n].include?(s)
    default
  end

  def parse_number(val)
    return nil if val.blank?
    # Limpia símbolos de moneda y texto como "+IVA"
    cleaned = val.to_s.gsub(/[^\d.,-]/, "").strip
    return nil if cleaned.blank?

    # Manejo de comas decimales (estilo CR/ES)
    if cleaned.include?(",") && !cleaned.include?(".")
      cleaned = cleaned.tr(",", ".")
    elsif cleaned.include?(",") && cleaned.include?(".")
      cleaned = cleaned.delete(",") # asume miles
    end
    begin
      BigDecimal(cleaned)
    rescue
      nil
    end
  end

  def parse_properties_string(raw)
    return {} if raw.blank?
    pairs = {}
    # Divide por | o ;
    raw.split(/\s*[|;]\s*/).each do |part|
      next if part.blank?
      # Divide por : o =
      k, v = part.include?(":") ? part.split(":", 2) : part.split("=", 2)
      next if k.blank? || v.blank?
      pairs[norm(k)] = norm(v)
    end
    pairs
  end

  def generate_report(total)
    {
      total: total, created: @created, updated: @updated, errors: @errors
    }.merge(@stats)
  end
end
