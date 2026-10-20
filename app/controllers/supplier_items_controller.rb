class SupplierItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_catalog_editor!
  before_action :set_supplier_item, only: %i[show edit update destroy]

  def index
    scope = SupplierItem.joins(:provider).includes(:provider, :review, :products)
      .order("providers.name ASC, supplier_items.name ASC")
    if params[:search].present?
      term = "%#{params[:search].strip}%"
      scope = scope.where("supplier_items.name LIKE ? OR supplier_items.sku LIKE ?", term, term)
    end
    scope = scope.where(provider_id: params[:provider_id]) if params[:provider_id].present?
    scope = scope.where(default_cost: nil) if params[:status] == "no_cost"
    scope = scope.where.missing(:products) if params[:status] == "no_products"
    # ponytail: sin paginación; agregar pagy si el listado pasa de unos pocos miles
    @supplier_items = scope
    @providers = Provider.order(:name)
  end

  def show
  end

  def new
    @supplier_item = SupplierItem.new
    @supplier_item.provider_id = params[:provider_id] if params[:provider_id]
  end

  def create
    @supplier_item = SupplierItem.new(supplier_item_params)

    if @supplier_item.save
      redirect_to @supplier_item,
        notice: "Pieza '#{@supplier_item.name}' creada correctamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @supplier_item.update(supplier_item_params)
      redirect_to @supplier_item,
        notice: "Pieza actualizada correctamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    deleted_name = @supplier_item.name
    @supplier_item.destroy

    redirect_to supplier_items_path,
      notice: "Pieza '#{deleted_name}' eliminada."
  end

  def import
    if params[:file].present?
      unless params[:file].original_filename.downcase.end_with?(".csv")
        return redirect_to supplier_items_path, alert: "Por favor sube un archivo en formato CSV."
      end

      temp_dir = Rails.root.join("tmp", "imports")
      FileUtils.mkdir_p(temp_dir) unless Dir.exist?(temp_dir)

      file_path = temp_dir.join("supplier_items_#{Time.now.to_i}_#{params[:file].original_filename}")
      File.binwrite(file_path, params[:file].read)

      ImportSupplierItemsJob.perform_later(file_path.to_s, current_user.id)

      redirect_to supplier_items_path,
        notice: "La importación de piezas ha comenzado. Los cambios aparecerán en breve."
    else
      redirect_to supplier_items_path, alert: "Debes seleccionar un archivo CSV para importar."
    end
  end

  private

  def set_supplier_item
    @supplier_item = SupplierItem.find(params[:id])
  end

  def supplier_item_params
    params.require(:supplier_item).permit(:provider_id, :name, :sku, :unit, :default_cost, :active, product_ids: [])
  end
end
