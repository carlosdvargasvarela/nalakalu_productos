class Inventory::AdjustmentsController < Inventory::BaseController
  def new
    @showrooms     = Showroom.active.order(is_main: :desc, name: :asc)
    @current_stock = InventoryMovement.net_stock_by_product_and_showroom
    product_ids    = @current_stock.keys.map(&:first).uniq
    @products      = Product.where(active: true, id: product_ids).order(:name)
  end

  def create
    @showrooms     = Showroom.active.order(is_main: :desc, name: :asc)
    @current_stock = InventoryMovement.net_stock_by_product_and_showroom
    adjustments    = params[:adjustments]&.to_unsafe_h || {}
    note_suffix    = params[:notes].presence ? " — #{params[:notes]}" : ""

    created = 0
    errors  = []

    ActiveRecord::Base.transaction do
      adjustments.each do |product_id_str, sala_map|
        sala_map.each do |showroom_id_str, actual_str|
          next if actual_str.blank?

          pid     = product_id_str.to_i
          sid     = showroom_id_str.to_i
          actual  = actual_str.to_f
          current = @current_stock[[pid, sid]]
          diff    = actual - current
          next if diff.zero?

          m = InventoryMovement.new(
            product_id:    pid,
            showroom_id:   sid,
            movement_type: diff > 0 ? "entry" : "exit",
            quantity:      diff.abs,
            status:        "resolved",
            source:        "manual",
            delivery_date: Date.current,
            notes:         "Ajuste de inventario#{note_suffix}"
          )

          if m.save
            created += 1
          else
            errors << "#{Product.find_by(id: pid)&.name}: #{m.errors.full_messages.join(', ')}"
          end
        end
      end

      raise ActiveRecord::Rollback if errors.any?
    end

    if errors.any?
      flash[:alert] = "Error al guardar ajustes: #{errors.first}."
      product_ids = @current_stock.keys.map(&:first).uniq
      @products   = Product.where(active: true, id: product_ids).order(:name)
      render :new, status: :unprocessable_entity
    else
      InventoryMovement.bust_stock_cache!
      redirect_to inventory_path,
        notice: created > 0 ? "#{created} ajuste(s) de inventario aplicados." : "Sin cambios — el stock ya coincidía."
    end
  end
end
