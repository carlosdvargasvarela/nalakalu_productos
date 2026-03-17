class PropertyValuesController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!
  before_action :set_property_value, only: %i[edit update destroy]

  def create
    @property = Property.find(params[:property_id])
    @property_value = @property.property_values.new(property_value_params)

    if @property_value.save
      redirect_to @property, notice: "Valor \"#{@property_value.value}\" añadido."
    else
      redirect_to @property, alert: @property_value.errors.full_messages.to_sentence
    end
  end

  def edit
    @property = @property_value.property
  end

  def update
    if @property_value.update(property_value_params)
      redirect_to @property_value.property, notice: "Valor actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    property = @property_value.property
    @property_value.destroy!
    redirect_to property, status: :see_other, notice: "Valor eliminado."
  end

  private

  def set_property_value
    @property_value = PropertyValue.find(params[:id])
  end

  def property_value_params
    params.require(:property_value).permit(:value, :active)
  end
end
