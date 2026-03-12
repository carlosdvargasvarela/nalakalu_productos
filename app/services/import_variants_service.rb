class ImportVariantsService
  include CsvImportHelper

  REQUIRED_HEADERS = %w[tipo_de_variante nombre codigo].freeze

  def self.call(file_path)
    new(file_path).import
  end

  def initialize(file_path)
    @file_path = file_path
    @created = 0
    @updated = 0
    @errors = []
  end

  def import
    result = CsvImportHelper.read_csv(@file_path)
    if result[:errors].any?
      @errors.concat(result[:errors])
      return generate_report(0)
    end

    rows = result[:rows]
    return generate_report(0) if rows.empty?

    validation = CsvImportHelper.validate_headers(rows.first.keys, REQUIRED_HEADERS)
    unless validation[:valid]
      @errors << validation[:message]
      return generate_report(0)
    end

    rows.each_with_index { |row, index| process_row(row, index + 2) }
    generate_report(rows.count)
  end

  private

  def process_row(row, line_number)
    type_name = CsvImportHelper.normalize_string(row["tipo_de_variante"])
    name = CsvImportHelper.normalize_string(row["nombre"])
    code = CsvImportHelper.normalize_string(row["codigo"])

    return if type_name.blank? || name.blank? || code.blank?

    ActiveRecord::Base.transaction do
      # Buscar el VariantType por nombre (no por ID)
      variant_type = VariantType.find_by(name: type_name)
      unless variant_type
        @errors << "Fila #{line_number}: Tipo de variante '#{type_name}' no encontrado. Créalo primero."
        raise ActiveRecord::Rollback
      end

      # Buscar proveedor por nombre si se proporcionó
      provider = nil
      provider_name = CsvImportHelper.normalize_string(row["proveedor"])
      if provider_name.present?
        provider = Provider.find_by(name: provider_name)
        unless provider
          @errors << "Fila #{line_number}: Proveedor '#{provider_name}' no encontrado. Se ignorará."
          # No hacemos rollback, simplemente dejamos provider en nil
        end
      end

      variant = Variant.find_or_initialize_by(
        variant_type: variant_type,
        code: code
      )
      is_new = variant.new_record?

      variant.name = name
      variant.provider = provider
      variant.provider_sku = CsvImportHelper.normalize_string(row["sku_proveedor"]).presence || code
      variant.active = true

      # Costo solo si viene en el CSV y es un número válido
      cost_raw = CsvImportHelper.normalize_string(row["costo"])
      if cost_raw.present?
        parsed = cost_raw.gsub(/[^0-9.,]/, "").tr(",", ".").to_d
        variant.cost = parsed if parsed > 0
      end

      variant.save!
      is_new ? @created += 1 : @updated += 1
    end
  rescue ActiveRecord::Rollback
    # ya registrado en @errors
  rescue => e
    @errors << "Fila #{line_number}: #{e.message}"
  end

  def generate_report(total)
    CsvImportHelper.generate_report(total: total, created: @created, updated: @updated, errors: @errors)
  end
end
