class Inventory::ConfigController < Inventory::BaseController
  before_action :authorize_admin!

  def show
    @config    = InventorySyncConfig.current
    @showrooms = Showroom.active.order(is_main: :desc, name: :asc)
  end

  def update_prefixes
    @showroom = Showroom.find(params[:showroom_id])
    prefixes  = params[:prefixes].to_s.split(",").map(&:strip).reject(&:blank?)
    @showroom.update!(order_number_prefixes: prefixes)
    redirect_to inventory_sync_config_path, notice: "Prefijos de #{@showroom.name} actualizados."
  end

  def test_classify
    delivery = {
      "id"                   => 0,
      "order_number"         => params[:order_number].to_s.strip,
      "delivery_date"        => Date.current.to_s,
      "client"               => { "name" => "Prueba" },
      "source_showroom"      => params[:source_showroom].present? ? { "code" => params[:source_showroom] } : nil,
      "destination_showroom" => params[:destination_showroom].present? ? { "code" => params[:destination_showroom] } : nil,
      "items"                => [{ "id" => 0, "product_name" => "Artículo de prueba", "quantity_delivered" => 1 }]
    }
    results = InventoryClassifier.classify(delivery)
    render json: {
      matched: results.any?,
      order_number: params[:order_number],
      movements: results.map { |r|
        { type: r.type, type_label: r.type == "entry" ? "Entrada" : "Salida", showroom: r.showroom.name }
      }
    }
  end

  def update_defaults
    InventorySyncConfig.current.update!(defaults_params)
    redirect_to inventory_sync_config_path, notice: "Defaults de fecha actualizados."
  end

  def update_schedule
    config  = InventorySyncConfig.current
    enabled = params.dig(:inventory_sync_config, :schedule_enabled) == "1"
    config.update!(schedule_params.merge(schedule_enabled: enabled))
    config.apply_schedule!
    redirect_to inventory_sync_config_path, notice: "Configuración de sync automático guardada."
  end

  private

  def defaults_params
    params.require(:inventory_sync_config).permit(:default_days_back, :default_days_forward)
  end

  def schedule_params
    params.require(:inventory_sync_config).permit(:schedule_cron, :schedule_days_back)
  end
end
