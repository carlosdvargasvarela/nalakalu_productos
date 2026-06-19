class Showroom < ApplicationRecord
  include SerializedArrayAttribute

  array_attribute :order_number_prefixes, :order_number_keywords, :inter_sala_keywords, :product_keywords

  has_many :inventory_movements, dependent: :restrict_with_error

  validates :name, presence: true
  validates :code, presence: true, uniqueness: { case_sensitive: false }

  before_validation :normalize_code
  before_save :demote_other_mains, if: -> { is_main? && (new_record? || is_main_changed?) }
  after_commit :bust_ids_cache, on: [:create, :destroy]

  scope :active, -> { where(active: true) }

  IDS_CACHE_KEY = "showrooms/ids"
  IDS_CACHE_TTL = 10.minutes

  # Salas casi nunca cambian, pero InventoryMovement#bust_stock_cache! recorre
  # todas sus IDs en cada movimiento guardado — cachear evita pegarle a la tabla
  # una vez por movimiento durante un sync grande.
  def self.cached_ids
    Rails.cache.fetch(IDS_CACHE_KEY, expires_in: IDS_CACHE_TTL) { ids }
  end

  private

  def normalize_code
    self.code = code.to_s.strip.upcase
  end

  def demote_other_mains
    Showroom.where(is_main: true).where.not(id: id).update_all(is_main: false)
  end

  def bust_ids_cache
    Rails.cache.delete(IDS_CACHE_KEY)
  end
end
