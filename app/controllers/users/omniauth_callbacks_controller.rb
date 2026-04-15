class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token

  def microsoft_graph
    auth = request.env["omniauth.auth"]
    @user = User.from_omniauth(auth)

    if @user
      # Usamos update_columns para saltear validaciones de Devise (no toca password)
      @user.update_columns(
        microsoft_provider: auth.provider,
        microsoft_uid: auth.uid,
        microsoft_token: auth.credentials.token,
        microsoft_refresh_token: auth.credentials.refresh_token,
        microsoft_token_expires_at: Time.at(auth.credentials.expires_at)
      )
      flash[:notice] = "Cuenta de Outlook conectada correctamente ✓"
      redirect_to profile_path
    else
      flash[:alert] = "No se encontró un usuario con el correo #{auth.info.email}."
      redirect_to profile_path
    end
  end

  def failure
    flash[:alert] = "Error al conectar con Microsoft: #{params[:message]}"
    redirect_to profile_path
  end
end
