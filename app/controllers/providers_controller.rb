class ProvidersController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_catalog_editor!
  before_action :set_provider, only: %i[show edit update destroy]

  def index
    scope = Provider.includes(:supplier_items, :review).order(:name)
    scope = scope.where("name LIKE ?", "%#{params[:search].strip}%") if params[:search].present?
    scope = scope.where(active: true) unless params[:hidden] == "1" # los grupos ocultos (inactivos) no estorban
    @providers = scope.review_is(params[:review]).review_by(params[:reviewer])
  end

  def show
    @supplier_items = @provider.supplier_items.active
      .includes(:supplier_item_properties)
      .order(:name)
      end

  def new
    @provider = Provider.new(active: true, category: "externo")
      end

  def edit
      end

  def create
    @provider = Provider.new(provider_params)

    if @provider.save
      redirect_to provider_path(@provider), notice: "Proveedor creado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @provider.update(provider_params)
      redirect_to provider_path(@provider), notice: "Proveedor actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @provider.destroy!
    redirect_to providers_path, notice: "Proveedor eliminado."
  end

  def import
    unless params[:file].present?
      redirect_to providers_path, alert: "Por favor, selecciona un archivo CSV."
      return
    end

    file = params[:file]
    tmp_path = Rails.root.join("tmp", "import_providers_#{Time.now.to_i}.csv")
    FileUtils.cp(file.tempfile.path, tmp_path)

    ImportProvidersJob.perform_later(tmp_path.to_s, current_user.id)
    redirect_to providers_path, notice: "Importación de proveedores iniciada."
  end

  private

  def set_provider
    @provider = Provider.find(params[:id])
  end

  def provider_params
    params.require(:provider).permit(
      :name, :contact_name, :email, :phone, :notes, :active, :category
    )
  end
end
