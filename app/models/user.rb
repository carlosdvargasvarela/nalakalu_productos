class User < ApplicationRecord
  # 1. Configuraciones de Capas (Devise, etc)
  devise :database_authenticatable, :registerable,
    :recoverable, :rememberable, :validatable,
    :omniauthable, omniauth_providers: [:microsoft_graph]

  # 2. Constantes y Validaciones
  ROLES = %w[admin showroom_admin seller].freeze
  validates :role, inclusion: {in: ROLES}

  # 3. Métodos de Clase (Static methods)
  def self.from_omniauth(auth)
    user = find_by(email: auth.info.email)

    if user
      user.update(
        microsoft_provider: auth.provider,
        microsoft_uid: auth.uid,
        microsoft_token: auth.credentials.token,
        microsoft_refresh_token: auth.credentials.refresh_token,
        microsoft_token_expires_at: Time.at(auth.credentials.expires_at)
      )
    end
    user
  end

  # 4. Métodos de Instancia Públicos
  def admin?
    role == "admin"
  end

  def showroom_admin?
    role == "showroom_admin"
  end

  def sala_admin?
    admin? || showroom_admin?
  end

  # Devuelve un token válido, renovándolo automáticamente si es necesario
  def active_microsoft_token
    return nil unless microsoft_token.present?

    if microsoft_token_expires_at.nil? || microsoft_token_expires_at <= Time.now + 1.minute
      refresh_microsoft_token!
    end
    microsoft_token
  end

  # Helper para saber si el usuario tiene Outlook conectado y vigente
  def outlook_connected?
    microsoft_token.present? && microsoft_token_expires_at > Time.current
  end

  private

  # 5. Métodos Privados (Lógica interna)
  def refresh_microsoft_token!
    return nil unless microsoft_refresh_token.present?

    strategy = OmniAuth::Strategies::MicrosoftGraph.new(
      nil,
      ENV["MICROSOFT_CLIENT_ID"],
      ENV["MICROSOFT_CLIENT_SECRET"]
    )

    client = strategy.client
    token_object = OAuth2::AccessToken.from_hash(client, {refresh_token: microsoft_refresh_token})

    begin
      new_token = token_object.refresh!

      update_columns(
        microsoft_token: new_token.token,
        microsoft_refresh_token: new_token.refresh_token || microsoft_refresh_token,
        microsoft_token_expires_at: Time.at(new_token.expires_at)
      )
      microsoft_token
    rescue => e
      Rails.logger.error "Error renovando token de Microsoft (User ID: #{id}): #{e.message}"
      nil
    end
  end
end
