class ProvidersController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!
  before_action :set_provider, only: %i[show edit update destroy]

  def index
    @providers = Provider.all
  end

  def show
  end

  def new
    @provider = Provider.new
    3.times { @provider.variants.build }
  end

  def edit
  end

  def create
    @provider = Provider.new(provider_params)

    respond_to do |format|
      if @provider.save
        format.html { redirect_to @provider, notice: "Proveedor creado exitosamente." }
        format.json { render :show, status: :created, location: @provider }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @provider.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @provider.update(provider_params)
        format.html { redirect_to @provider, notice: "Proveedor actualizado exitosamente." }
        format.json { render :show, status: :ok, location: @provider }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @provider.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @provider.destroy!

    respond_to do |format|
      format.html { redirect_to providers_path, status: :see_other, notice: "Proveedor eliminado." }
      format.json { head :no_content }
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
    params.require(:provider).permit(:name, :contact_name, :email, :phone, :notes, :active, :category,
      variants_attributes: [
        :id, :variant_type_id, :name, :code, :provider_sku, :cost, :active, :_destroy
      ])
  end
end
