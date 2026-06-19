class Showroom < ApplicationRecord
  include SerializedArrayAttribute

  array_attribute :order_number_prefixes, :order_number_keywords, :inter_sala_keywords, :product_keywords

  has_many :inventory_movements, dependent: :restrict_with_error

  validates :name, presence: true
  validates :code, presence: true, uniqueness: { case_sensitive: false }

  before_validation :normalize_code
  before_save :demote_other_mains, if: -> { is_main? && (new_record? || is_main_changed?) }

  scope :active, -> { where(active: true) }

  private

  def normalize_code
    self.code = code.to_s.strip.upcase
  end

  def demote_other_mains
    Showroom.where(is_main: true).where.not(id: id).update_all(is_main: false)
  end
end
