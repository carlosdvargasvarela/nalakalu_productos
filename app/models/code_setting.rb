class CodeSetting < ApplicationRecord
  serialize :stock_sala_options, coder: JSON

  validates :max_chars_per_line, presence: true, numericality: {greater_than: 0, less_than: 200}
  validates :max_lines, presence: true, numericality: {greater_than: 0, less_than: 50}
  validates :prefix_length, presence: true, numericality: {greater_than: 0, less_than: 10}
  validates :default_separator, presence: true

  def self.current
    where(name: "Configuración General").first_or_create!(
      max_chars_per_line: 30,
      max_lines: 5,
      prefix_length: 2,
      default_separator: "-",
      stock_sala_options: ["STOCK DE SALA"]
    )
  end

  def stock_sala_options_array
    raw = read_attribute_before_type_cast("stock_sala_options")

    parsed =
      case raw
      when nil
        []
      when Array
        raw
      when String
        begin
          JSON.parse(raw)
        rescue JSON::ParserError
          [raw]
        end
      else
        Array(raw)
      end

    Array(parsed).map(&:to_s).map(&:strip).reject(&:blank?)
  end
end
