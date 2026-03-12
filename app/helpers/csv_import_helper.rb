require "csv"

module CsvImportHelper
  def self.read_csv(file_path)
    rows = []
    errors = []

    begin
      content = File.read(file_path, encoding: "bom|utf-8")

      CSV.parse(content, headers: true, skip_blanks: true).each do |row|
        normalized_row = {}
        row.to_h.each do |key, value|
          header = normalize_header(key.to_s)
          normalized_row[header] = value.to_s.strip
        end
        rows << normalized_row
      end

      {rows: rows, errors: errors}
    rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
      begin
        content = File.read(file_path, encoding: "ISO-8859-1").encode("UTF-8")
        CSV.parse(content, headers: true, skip_blanks: true).each do |row|
          normalized_row = {}
          row.to_h.each do |key, value|
            header = normalize_header(key.to_s)
            normalized_row[header] = value.to_s.strip
          end
          rows << normalized_row
        end
        {rows: rows, errors: errors}
      rescue => e
        errors << "Error de codificación: #{e.message}"
        {rows: [], errors: errors}
      end
    rescue => e
      errors << "Error al leer CSV: #{e.message}"
      {rows: [], errors: errors}
    end
  end

  def self.normalize_header(header)
    header = header.downcase.strip
    header = I18n.transliterate(header)
    header = header.gsub(/\s+/, "_")
    header.gsub(/[^a-z0-9_]/, "")
  end

  def self.validate_headers(actual_headers, required_headers)
    missing = required_headers - actual_headers
    {
      valid: missing.empty?,
      message: missing.any? ? "Faltan columnas: #{missing.join(", ")}" : nil
    }
  end

  def self.normalize_string(value)
    return nil if value.nil?
    value = value.to_s.strip
    value.blank? ? nil : value
  end

  def self.to_boolean(value)
    return true if value.nil? || value.to_s.strip.empty?
    ["si", "sí", "s", "yes", "y", "true", "1"].include?(value.to_s.downcase.strip)
  end

  def self.to_decimal(value)
    return nil if value.nil? || value.to_s.strip.empty?
    BigDecimal(value.to_s.tr(",", "."))
  rescue ArgumentError
    nil
  end

  def self.generate_report(total:, created:, updated:, errors:)
    {
      total: total,
      created: created,
      updated: updated,
      errors: errors,
      success: errors.empty?
    }
  end
end
