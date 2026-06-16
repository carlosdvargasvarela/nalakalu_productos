class InventoryMovement < ApplicationRecord
  belongs_to :inventory_sync, optional: true
  belongs_to :product, optional: true
  belongs_to :showroom, optional: true

  TYPES    = %w[entry exit initial].freeze
  STATUSES = %w[resolved unresolved ignored].freeze
  SOURCES  = %w[synced manual].freeze
  FLAGS    = %w[stock_missing].freeze

  validates :movement_type, inclusion: { in: TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :source, inclusion: { in: SOURCES }
  validates :flag, inclusion: { in: FLAGS }, allow_nil: true
  validates :quantity, numericality: { greater_than: 0 }

  scope :resolved,   -> { where(status: "resolved") }
  scope :unresolved, -> { where(status: "unresolved") }
  scope :ignored,    -> { where(status: "ignored") }
  scope :flagged,    -> { where.not(flag: nil) }

  scope :confirmed_only, -> {
    joins("LEFT OUTER JOIN inventory_syncs ON inventory_syncs.id = inventory_movements.inventory_sync_id")
      .where(
        "inventory_movements.inventory_sync_id IS NULL OR inventory_syncs.status = 'confirmed'"
      )
  }

  STOCK_CACHE_TTL = 5.minutes

  after_commit :bust_stock_cache, on: [:create, :update, :destroy]

  # Llamar explícitamente después de cualquier escritura que no dispare
  # callbacks de InventoryMovement pero afecte qué cuenta como stock:
  # update_all sobre movimientos, o cambiar inventory_syncs.status (el JOIN
  # de confirmed_only depende de esa columna, no de los movimientos mismos).
  def self.bust_stock_cache!
    Rails.cache.delete("inventory_movements/stock_by_product_and_showroom")
    Showroom.ids.each { |id| Rails.cache.delete("inventory_movements/stock_by_showroom/#{id}") }
  end

  # Agrega TODO el historial de movimientos — no hay filtro selectivo que
  # un índice pueda explotar, así que cachear es lo que realmente evita
  # recalcularlo en cada carga del dashboard.
  def self.stock_by_product_and_showroom
    Rails.cache.fetch("inventory_movements/stock_by_product_and_showroom", expires_in: STOCK_CACHE_TTL) do
      confirmed_only
        .resolved
        .where.not(product_id: nil)
        .group(:product_id, :showroom_id, :movement_type)
        .sum(:quantity)
    end
  end

  def self.stock_by_showroom(showroom_id)
    Rails.cache.fetch("inventory_movements/stock_by_showroom/#{showroom_id}", expires_in: STOCK_CACHE_TTL) do
      confirmed_only
        .resolved
        .where.not(product_id: nil)
        .where(showroom_id: showroom_id)
        .group(:product_id, :movement_type)
        .sum(:quantity)
    end
  end

  def self.current_stock_for(product_id:, showroom_id:)
    sums = confirmed_only
      .resolved
      .where(product_id: product_id, showroom_id: showroom_id)
      .group(:movement_type)
      .sum(:quantity)

    sums.fetch("entry", 0) + sums.fetch("initial", 0) - sums.fetch("exit", 0)
  end

  def type_label
    case movement_type
    when "entry"   then "Entrada"
    when "exit"    then "Salida"
    when "initial" then "Stock inicial"
    end
  end

  def source_label
    source == "manual" ? "Manual" : "Automático"
  end

  private

  def bust_stock_cache
    self.class.bust_stock_cache!
  end
end
