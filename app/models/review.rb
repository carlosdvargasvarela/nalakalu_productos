class Review < ApplicationRecord
  STATUSES = %w[pending approved needs_changes].freeze
  LABELS = {"pending" => "Pendiente", "approved" => "Aprobado", "needs_changes" => "Requiere cambios"}.freeze

  belongs_to :reviewable, polymorphic: true
  belongs_to :user, optional: true

  validates :status, inclusion: {in: STATUSES}
  validates :note, presence: {message: "es obligatorio si requiere cambios"}, if: -> { status == "needs_changes" }
end
