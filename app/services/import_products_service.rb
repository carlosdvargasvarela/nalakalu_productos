class ImportProductsService
  include CsvImportHelper

  REQUIRED_HEADERS = ["nombre", "codigo_base"].freeze

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
    nombre = CsvImportHelper.normalize_string(row["nombre"])
    codigo_base = CsvImportHelper.normalize_string(row["codigo_base"])
    descripcion = CsvImportHelper.normalize_string(row["descripcion"])

    unless nombre && codigo_base
      @errors << "Fila #{line_number}: 'nombre' y 'codigo_base' son obligatorios"
      return
    end

    product = Product.find_or_initialize_by(base_code: codigo_base)

    if product.new_record?
      product.name = nombre
      product.description = descripcion
      product.active = true

      if product.save
        @created += 1
      else
        @errors << "Fila #{line_number}: #{product.errors.full_messages.join(", ")}"
      end
    else
      # Actualiza nombre y descripción si ya existe
      product.name = nombre
      product.description = descripcion if descripcion.present?

      if product.save
        @updated += 1
      else
        @errors << "Fila #{line_number}: #{product.errors.full_messages.join(", ")}"
      end
    end
  end

  def generate_report(total)
    {
      total: total,
      created: @created,
      updated: @updated,
      errors: @errors
    }
  end
end
