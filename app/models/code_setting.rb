# app/models/code_setting.rb
class CodeSetting < ApplicationRecord
  validates :max_chars_per_line, presence: true, numericality: {greater_than: 0, less_than: 200}
  validates :max_lines, presence: true, numericality: {greater_than: 0, less_than: 50}
  validates :prefix_length, presence: true, numericality: {greater_than: 0, less_than: 10}
  validates :default_separator, presence: true
  validates :stock_sala_label, presence: true

  # Método de conveniencia para obtener la configuración activa
  def self.current
    first_or_create!(name: "Configuración General")
  end
end
