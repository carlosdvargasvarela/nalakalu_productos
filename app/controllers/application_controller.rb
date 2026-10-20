class ApplicationController < ActionController::Base
  include Pagy::Method

  allow_browser versions: :modern

  layout :layout_by_resource
  before_action :set_change_context

  def authorize_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: "No tienes permisos para realizar esta acción."
    end
  end

  def authorize_catalog_editor!
    unless current_user&.catalog_editor?
      redirect_to root_path, alert: "No tienes permisos para realizar esta acción."
    end
  end

  def authorize_sala_admin!
    unless current_user&.sala_admin?
      redirect_to root_path, alert: "No tienes permisos para realizar esta acción."
    end
  end

  private

  # Cada petición que escribe es un "lote" en el historial (ver ChangeLog).
  def set_change_context
    Current.user = current_user
    Current.batch_id = SecureRandom.uuid unless request.get? || request.head?
  end

  def layout_by_resource
    if devise_controller?
      "auth"
    else
      "application"
    end
  end
end
