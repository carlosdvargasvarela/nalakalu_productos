# Fila del export de QuickBooks. Solo consulta: nunca se edita desde la app.
class QbItem < ApplicationRecord
  validates :code, presence: true, uniqueness: true

  # QuickBooks llena los nombres con puntos ("Mesa de Comedor.."): se quitan los repetidos.
  def self.clean_name(text)
    text.to_s.gsub(/\.{2,}/, " ").squish
  end

  def self.for_code(code)
    find_by(code: code.to_s.strip)
  end

  def name = self.class.clean_name(raw_description)
end
