class InventoryMovement < ApplicationRecord
  belongs_to :inventory_sync, optional: true
  belongs_to :product, optional: true

  TYPES   = %w[entry exit initial].freeze
  SALAS   = %w[SP SE SG].freeze
  STATUSES = %w[resolved unresolved ignored].freeze

  SALA_LABELS = { "SP" => "Sala Palmares", "SE" => "Sala Escazú", "SG" => "Sala Guanacaste" }.freeze

  validates :movement_type, inclusion: { in: TYPES }
  validates :sala, inclusion: { in: SALAS }
  validates :status, inclusion: { in: STATUSES }
  validates :quantity, numericality: { greater_than: 0 }

  scope :resolved,   -> { where(status: "resolved") }
  scope :unresolved, -> { where(status: "unresolved") }
  scope :ignored,    -> { where(status: "ignored") }

  scope :confirmed_only, -> {
    joins("LEFT OUTER JOIN inventory_syncs ON inventory_syncs.id = inventory_movements.inventory_sync_id")
      .where(
        "inventory_movements.inventory_sync_id IS NULL OR inventory_syncs.status = 'confirmed'"
      )
  }

  def self.stock_by_product_and_sala
    confirmed_only
      .resolved
      .where.not(product_id: nil)
      .group(:product_id, :sala, :movement_type)
      .sum(:quantity)
  end

  def sala_label
    SALA_LABELS[sala] || sala
  end

  def type_label
    case movement_type
    when "entry"  then "Entrada"
    when "exit"   then "Salida"
    when "initial" then "Stock inicial"
    end
  end
end
