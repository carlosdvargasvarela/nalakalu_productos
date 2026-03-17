class PropertiesController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!
  before_action :set_property, only: %i[show edit update destroy]

  def index
    @properties = Property.includes(:property_values)
      .order(:name)
  end

  def show
    @property_values = @property.property_values.order(:value)
    @new_value = PropertyValue.new(property: @property)
  end

  def new
    @property = Property.new
  end

  def edit
  end

  def create
    @property = Property.new(property_params)
    if @property.save
      redirect_to @property, notice: "Propiedad creada exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @property.update(property_params)
      redirect_to @property, notice: "Propiedad actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @property.destroy!
    redirect_to properties_path, status: :see_other, notice: "Propiedad eliminada."
  end

  private

  def set_property
    @property = Property.find(params[:id])
  end

  def property_params
    params.require(:property).permit(:name, :active)
  end
end
