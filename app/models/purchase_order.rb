# app/models/purchase_order.rb
class PurchaseOrder < ApplicationRecord
  belongs_to :provider
  has_many :purchase_order_items, dependent: :destroy
  accepts_nested_attributes_for :purchase_order_items, allow_destroy: true

  STATUSES = %w[borrador enviado confirmado recibido cancelado].freeze

  validates :number, presence: true, uniqueness: true
  validates :status, inclusion: {in: STATUSES}

  before_validation :set_defaults, on: :create

  def total_amount
    purchase_order_items.reject(&:marked_for_destruction?).sum(&:total)
  end

  private

  def set_defaults
    self.status ||= "borrador"
    self.issued_date ||= Date.current
    self.number ||= generate_number
  end

  def generate_number
    last = begin
      PurchaseOrder.maximum(:number.to_s)
    rescue
      nil
    end
    last_num = last.to_s.gsub(/\D/, "").to_i
    "OC-#{(last_num + 1).to_s.rjust(4, "0")}"
  end
end
