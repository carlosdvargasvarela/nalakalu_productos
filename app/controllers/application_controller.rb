class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :authenticate_user!

  def authorize_admin!
    unless current_user&.role == 'admin'
      redirect_to root_path, alert: "No tienes permisos para realizar esta acción."
    end
  end
end