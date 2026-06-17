require "roo"

module XlsxImportHelper
  def self.read_xlsx(file_path)
    sheet = Roo::Excelx.new(file_path).sheet(0)
    return {rows: [], errors: ["El archivo está vacío."]} if (sheet.last_row || 0) < 1

    headers = sheet.row(1).map { |h| CsvImportHelper.normalize_header(h.to_s) }
    rows = []

    (2..sheet.last_row).each do |i|
      values = sheet.row(i)
      next if values.compact.all? { |v| v.to_s.strip.empty? }

      row = {}
      headers.each_with_index { |header, idx| row[header] = values[idx].to_s.strip }
      rows << row
    end

    {rows: rows, errors: []}
  rescue => e
    {rows: [], errors: ["Error al leer el archivo Excel: #{e.message}"]}
  end
end
