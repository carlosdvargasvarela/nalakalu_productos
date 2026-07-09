class Showroom < ApplicationRecord
  include SerializedArrayAttribute

  array_attribute :order_number_prefixes, :order_number_keywords, :inter_sala_keywords, :product_keywords

  has_many :inventory_movements, dependent: :restrict_with_error

  validates :name, presence: true
  validates :code, presence: true, uniqueness: { case_sensitive: false }

  before_validation :normalize_code
  before_save :demote_other_mains, if: -> { is_main? && (new_record? || is_main_changed?) }
  after_commit :bust_ids_cache, on: [:create, :update, :destroy]

  scope :active, -> { where(active: true) }

  IDS_CACHE_KEY = "showrooms/ids"
  IDS_CACHE_TTL = 10.minutes
  ACTIVE_CACHE_KEY = "showrooms/active_ordered"

  # Salas casi nunca cambian, pero InventoryMovement#bust_stock_cache! recorre
  # todas sus IDs en cada movimiento guardado — cachear evita pegarle a la tabla
  # una vez por movimiento durante un sync grande.
  def self.cached_ids
    Rails.cache.fetch(IDS_CACHE_KEY, expires_in: IDS_CACHE_TTL) { ids }
  end

  # Todas las vistas del módulo de inventario piden esta misma lista (para
  # tablas y selects) en cada request — cachear evita repetir la query en
  # cada carga de página.
  def self.cached_active_ordered
    Rails.cache.fetch(ACTIVE_CACHE_KEY, expires_in: IDS_CACHE_TTL) do
      active.order(is_main: :desc, name: :asc).to_a
    end
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
    Rails.cache.delete(ACTIVE_CACHE_KEY)
  end
end
