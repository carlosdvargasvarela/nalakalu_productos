class ImportProvidersService
  include CsvImportHelper

  # Headers ahora en snake_case gracias al nuevo helper
  REQUIRED_HEADERS = ["nombre"].freeze

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
    name = CsvImportHelper.normalize_string(row["nombre"])
    return if name.blank?

    ActiveRecord::Base.transaction do
      provider = Provider.find_or_initialize_by(name: name)
      is_new = provider.new_record?

      # Los keys del row ahora son seguros (snake_case)
      provider.contact_name = CsvImportHelper.normalize_string(row["nombre_de_contacto"])
      provider.email = CsvImportHelper.normalize_string(row["email"])
      provider.phone = CsvImportHelper.normalize_string(row["telefono"])
      provider.notes = CsvImportHelper.normalize_string(row["notas"])
      provider.active = CsvImportHelper.to_boolean(row["activo"])

      provider.save!
      is_new ? @created += 1 : @updated += 1
    end
  rescue => e
    @errors << "Fila #{line_number}: #{e.message}"
  end

  def generate_report(total)
    CsvImportHelper.generate_report(total: total, created: @created, updated: @updated, errors: @errors)
  end
end
