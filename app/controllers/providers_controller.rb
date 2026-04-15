class ProvidersController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!
  before_action :set_provider, only: %i[show edit update destroy]

  def index
    @providers = Provider.includes(:supplier_items).order(:name)
    @selected = params[:selected_id].present? ? Provider.find_by(id: params[:selected_id]) : nil

    @stats = {
      total: Provider.count,
      active: Provider.where(active: true).count,
      internal: Provider.where(category: "interno").count,
      external: Provider.where(category: "externo").count
    }
  end

  def show
    @supplier_items = @provider.supplier_items.active
      .includes(:supplier_item_properties)
      .order(:name)
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def new
    @provider = Provider.new(active: true, category: "externo")
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def edit
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def create
    @provider = Provider.new(provider_params)

    if @provider.save
      respond_to do |format|
        format.html { redirect_to providers_path(selected_id: @provider.id), notice: "Proveedor creado." }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    if @provider.update(provider_params)
      @supplier_items = @provider.supplier_items.active
        .includes(:supplier_item_properties).order(:name)
      respond_to do |format|
        format.html { redirect_to providers_path(selected_id: @provider.id), notice: "Proveedor actualizado." }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @provider.destroy!
    respond_to do |format|
      format.html { redirect_to providers_path, notice: "Proveedor eliminado." }
      format.turbo_stream
    end
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
