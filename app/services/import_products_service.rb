class ImportProductsService
  include CsvImportHelper

  REQUIRED_HEADERS = [
    "producto",
    "codigo_base",
    "tipo_variante",
    "variante_nombre",
    "variante_codigo",
    "proveedor"
  ].freeze

  def self.call(file_path)
    new(file_path).import
  end

  def initialize(file_path)
    @file_path = file_path
    @created_products = 0
    @created_rules = 0
    @created_variants = 0
    @errors = []
    @product_positions = {}
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

    # Validar headers
    actual_headers = rows.first.keys
    Rails.logger.info "🔍 Headers detectados: #{actual_headers.inspect}"

    validation = CsvImportHelper.validate_headers(actual_headers, REQUIRED_HEADERS)
    unless validation[:valid]
      @errors << validation[:message]
      Rails.logger.error "❌ #{validation[:message]}"
      return generate_report(0)
    end

    # Procesar cada fila
    rows.each_with_index do |row, index|
      process_row(row, index + 2)
    end

    generate_report(rows.count)
  end

  private

  def process_row(row, line_number)
    ActiveRecord::Base.transaction do
      # 1. Proveedor
      provider_name = CsvImportHelper.normalize_string(row["proveedor"])
      unless provider_name
        @errors << "Fila #{line_number}: Falta el proveedor"
        raise ActiveRecord::Rollback
      end
      provider = Provider.find_or_create_by!(name: provider_name)

      # 2. Tipo de Variante
      vt_name = CsvImportHelper.normalize_string(row["tipo_variante"])
      unless vt_name
        @errors << "Fila #{line_number}: Falta el tipo de variante"
        raise ActiveRecord::Rollback
      end
      variant_type = VariantType.find_or_create_by!(name: vt_name)

      # 3. Variante
      v_name = CsvImportHelper.normalize_string(row["variante_nombre"])
      v_code = CsvImportHelper.normalize_string(row["variante_codigo"])

      unless v_name && v_code
        @errors << "Fila #{line_number}: Falta nombre o código de variante"
        raise ActiveRecord::Rollback
      end

      variant = Variant.find_or_initialize_by(
        variant_type: variant_type,
        code: v_code
      )

      if variant.new_record?
        variant.name = v_name
        variant.provider = provider
        variant.cost = CsvImportHelper.to_decimal(row["costo"])
        variant.provider_sku = CsvImportHelper.normalize_string(row["sku_proveedor"])
        variant.active = CsvImportHelper.to_boolean(row["activo"])
        variant.save!
        @created_variants += 1
      end

      # 4. Producto
      p_name = CsvImportHelper.normalize_string(row["producto"])
      p_code = CsvImportHelper.normalize_string(row["codigo_base"])

      unless p_name && p_code
        @errors << "Fila #{line_number}: Falta nombre o código del producto"
        raise ActiveRecord::Rollback
      end

      product = Product.find_or_initialize_by(base_code: p_code)
      if product.new_record?
        product.name = p_name
        product.active = true
        product.save!
        @created_products += 1
      end

      # 5. Regla
      label = CsvImportHelper.normalize_string(row["etiqueta"])

      rule = ProductVariantRule.find_or_initialize_by(
        product: product,
        variant_type: variant_type,
        label: label
      )

      if rule.new_record?
        @product_positions[p_code] ||= 0
        @product_positions[p_code] += 1
        rule.position = @product_positions[p_code]
        @created_rules += 1
      end

      separator = CsvImportHelper.normalize_string(row["separador"])
      rule.separator = separator.presence || "-"
      rule.required = CsvImportHelper.to_boolean(row["obligatorio"])
      rule.save!
    end
  rescue => e
    @errors << "Fila #{line_number}: #{e.message}"
    Rails.logger.error "❌ Error en fila #{line_number}: #{e.message}"
  end

  def generate_report(total)
    {
      total: total,
      products: @created_products,
      rules: @created_rules,
      variants: @created_variants,
      errors: @errors
    }
  end
end
