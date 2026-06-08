# app/controllers/showrooms_controller.rb
class ShowroomsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!
  before_action :set_showroom, only: %i[edit update destroy]

  def index
    @showrooms = Showroom.order(is_main: :desc, name: :asc)
  end

  def new
    @showroom = Showroom.new(active: true)
  end

  def edit
  end

  def create
    @showroom = Showroom.new(showroom_params)
    if @showroom.save
      redirect_to showrooms_path, notice: "Sala creada exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @showroom.update(showroom_params)
      redirect_to showrooms_path, notice: "Sala actualizada exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @showroom.destroy
      redirect_to showrooms_path, notice: "Sala eliminada."
    else
      redirect_to showrooms_path, alert: @showroom.errors.full_messages.to_sentence
    end
  end

  private

  def set_showroom
    @showroom = Showroom.find(params[:id])
  end

  def showroom_params
    params.require(:showroom).permit(
      :name, :code, :is_main, :active,
      order_number_prefixes: [],
      order_number_keywords: [],
      inter_sala_keywords: [],
      product_keywords: []
    )
  end
end
