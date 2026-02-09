class ProvidersController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!
  before_action :set_provider, only: %i[ show edit update destroy ]

  def index
    @providers = Provider.all
  end

  def show
  end

  def new
    @provider = Provider.new
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

  private
    def set_provider
      @provider = Provider.find(params[:id])
    end

    def provider_params
      params.require(:provider).permit(:name, :contact_name, :email, :phone, :notes, :active)
    end
end