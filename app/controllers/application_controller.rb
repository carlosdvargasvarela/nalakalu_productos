class ApplicationController < ActionController::Base
  include Pagy::Method

  allow_browser versions: :modern

  layout :layout_by_resource

  def authorize_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: "No tienes permisos para realizar esta acción."
    end
  end

  def authorize_sala_admin!
    unless current_user&.sala_admin?
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
