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
