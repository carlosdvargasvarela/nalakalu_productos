class InventorySync < ApplicationRecord
  has_many :inventory_movements, dependent: :destroy

  STATUSES = %w[pending_review confirmed].freeze
  KINDS    = %w[logistics_sync bulk_upload].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :kind, inclusion: { in: KINDS }
  validates :from_date, :to_date, presence: true

  scope :pending, -> { where(status: "pending_review") }
  scope :confirmed, -> { where(status: "confirmed") }
  scope :ordered, -> { order(synced_at: :desc) }

  # Evita que dos sincronizaciones automáticas pendientes se superpongan en fechas:
  # si la segunda corre antes de que la primera se confirme, los movimientos de la
  # primera se reasignan silenciosamente a la segunda y su contador queda obsoleto.
  def self.pending_logistics_sync_overlapping(from, to)
    pending.where(kind: "logistics_sync")
      .where("from_date <= ? AND to_date >= ?", to, from)
      .order(:from_date)
      .first
  end

  def confirm!
    return false if inventory_movements.unresolved.any?
    update!(status: "confirmed")
    InventoryMovement.bust_stock_cache!
    true
  end

  def confirmable?
    inventory_movements.unresolved.none?
  end

  def status_label
    status == "confirmed" ? "Confirmado" : "Pendiente revisión"
  end

  def bulk_upload?
    kind == "bulk_upload"
  end
end
