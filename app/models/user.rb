class User < ApplicationRecord
  # Eliminamos :registerable para que no haya registro público
  devise :database_authenticatable,
    :recoverable, :rememberable, :validatable

  # Roles válidos
  ROLES = %w[admin seller].freeze
  validates :role, inclusion: {in: ROLES}

  def admin?
    role == "admin"
  end
end
