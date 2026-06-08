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

  def self.stock_by_product_and_showroom
    confirmed_only
      .resolved
      .where.not(product_id: nil)
      .group(:product_id, :showroom_id, :movement_type)
      .sum(:quantity)
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
end
