class CodeSettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_code_setting

  def edit
    @variant_types = VariantType.order(:position, :name)
  end

  def update
    # Primero sanitizamos la columna directamente en BD para evitar
    # que el serializer JSON explote al leer el valor corrupto anterior
    safe_options = Array(params.dig(:code_setting, :stock_sala_options))
      .map(&:to_s).map(&:strip).reject(&:blank?)
    @code_setting.update_columns(stock_sala_options: safe_options.to_json)

    # Ahora el registro en BD tiene JSON válido → update normal es seguro
    if @code_setting.reload.update(code_setting_params)
      redirect_to edit_code_setting_path, notice: "Configuración actualizada con éxito."
    else
      @variant_types = VariantType.order(:position, :name)
      render :edit, status: :unprocessable_entity
    end
  end

  def update_variant_type_order
    params[:order].each_with_index do |id, index|
      VariantType.where(id: id).update_all(position: index + 1)
    end
    head :ok
  end

  private

  def set_code_setting
    @code_setting = CodeSetting.current
  end

  def require_admin!
    redirect_to root_path, alert: "No autorizado." unless current_user&.role == "admin"
  end

  def code_setting_params
    params.require(:code_setting).permit(
      :max_chars_per_line,
      :max_lines,
      :default_separator,
      :show_stock_sala,
      :use_prefixes,
      :prefix_length,
      stock_sala_options: []
    )
  end
end
