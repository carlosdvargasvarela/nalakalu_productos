class ApplicationController < ActionController::Base
  include Pagy::Method

  # Solo permite navegadores modernos (webp, web push, import maps, CSS nesting, :has)
  allow_browser versions: :modern

  before_action :authenticate_user!

  layout :layout_by_resource

  def authorize_admin!
    unless current_user&.role == "admin"
      redirect_to root_path, alert: "No tienes permisos para realizar esta acción."
    end
  end

  private

  def layout_by_resource
    if devise_controller?
      "auth"
    else
      "application"
    end
  end
end
