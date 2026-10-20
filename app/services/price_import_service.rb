# Precios de venta por lote desde CSV o Excel (.xlsx). Dos pasos: preview (no escribe nada) y apply.
require "csv"

class PriceImportService
  CODE_HEADERS = %w[codigo_base codigo base_code cod].freeze
  PRICE_HEADERS = %w[precio precio_nuevo precio_venta price list_price].freeze

  # Acepta "450000", "450.000", "450.000,50", "450,000.50", "₡450.000", "1,5". Nil si no es un número.
  # ponytail: "1.500" se lee como 1500 (convención local: el punto separa miles); un precio con 3 decimales no es posible.
  def self.parse_price(raw)
    s = raw.to_s.gsub(/[₡$\s]|crc|colones/i, "")
    return nil if s.empty?

    if s.include?(",") && s.include?(".")
      s = (s.rindex(",") > s.rindex(".")) ? s.delete(".").tr(",", ".") : s.delete(",")
    elsif s.include?(",")
      s = s.match?(/\A\d{1,3}(,\d{3})+\z/) ? s.delete(",") : s.tr(",", ".")
    elsif s.count(".") > 1 || s.match?(/\A\d{1,3}\.\d{3}\z/)
      s = s.delete(".")
    end
    BigDecimal(s) if s.match?(/\A\d+(\.\d+)?\z/)
  end

  def self.template(format)
    products = Product.order(:name)
    if format == "csv"
      CSV.generate(col_sep: ",") do |csv|
        csv << ["Código base", "Producto", "Precio"]
        products.each { csv << [_1.base_code, _1.name, _1.list_price&.to_s("F")] }
      end
    else
      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: "Precios") do |sheet|
        sheet.add_row ["Código base", "Producto", "Precio"], b: true
        products.each { |p| sheet.add_row [p.base_code, p.name, p.list_price&.to_f], types: [:string, :string, :float] }
        sheet.column_widths 18, 60, 16
      end
      package.to_stream.read
    end
  end

  # => {changes: [{id:, code:, name:, old:, new:}], unchanged:, errors: [..]}
  def self.preview(path, filename)
    data = filename.to_s.downcase.end_with?(".xlsx") ? XlsxImportHelper.read_xlsx(path) : CsvImportHelper.read_csv(path)
    return {changes: [], unchanged: 0, errors: data[:errors]} if data[:errors].any?

    rows = data[:rows]
    keys = rows.first&.keys || []
    code_key = (CODE_HEADERS & keys).first
    price_key = (PRICE_HEADERS & keys).first
    unless code_key && price_key
      return {changes: [], unchanged: 0, errors: ["No encontré las columnas. Necesito «Código base» y «Precio» (usa la plantilla)."]}
    end

    by_code = Product.all.group_by(&:base_code)
    result = {changes: [], unchanged: 0, errors: []}
    rows.each_with_index do |row, i|
      line = i + 2
      code = row[code_key].to_s.strip
      next if code.empty?

      products = by_code[code]
      next result[:errors] << "Fila #{line}: no existe un producto con código «#{code}»." if products.blank?
      next result[:errors] << "Fila #{line}: el código «#{code}» está repetido en el catálogo." if products.size > 1
      next if row[price_key].to_s.strip.empty? # sin precio en el archivo = no tocar

      price = parse_price(row[price_key])
      next result[:errors] << "Fila #{line}: precio no válido «#{row[price_key]}»." if price.nil?

      product = products.first
      if product.list_price == price
        result[:unchanged] += 1
      else
        result[:changes] << {id: product.id, code: code, name: product.name, old: product.list_price&.to_s("F"), new: price.to_s("F")}
      end
    end
    result
  end

  def self.apply(changes)
    Product.transaction do
      changes.each { |c| Product.find(c["id"]).update!(list_price: BigDecimal(c["new"].to_s)) }
    end
    changes.size
  end
end
