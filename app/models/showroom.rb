class Showroom < ApplicationRecord
  ARRAY_ATTRIBUTES = %w[
    order_number_prefixes order_number_keywords inter_sala_keywords product_keywords
  ].freeze

  ARRAY_ATTRIBUTES.each { |attr| serialize attr, coder: JSON }

  validates :name, presence: true
  validates :code, presence: true, uniqueness: { case_sensitive: false }

  before_validation :normalize_code
  before_save :demote_other_mains, if: -> { is_main? && (new_record? || is_main_changed?) }

  scope :active, -> { where(active: true) }

  ARRAY_ATTRIBUTES.each do |attr|
    define_method("#{attr}_array") { array_attribute(attr) }
  end

  private

  def normalize_code
    self.code = code.to_s.strip.upcase
  end

  def demote_other_mains
    Showroom.where(is_main: true).where.not(id: id).update_all(is_main: false)
  end

  def array_attribute(attr_name)
    raw = read_attribute_before_type_cast(attr_name)

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
