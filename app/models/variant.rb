class Variant < ApplicationRecord
  belongs_to :variant_type
  belongs_to :provider
  
  validates :name, :code, presence: true
  validates :code, uniqueness: { scope: :variant_type_id, message: "ya existe para este tipo de variante" }
end