class UsersController < ApplicationController
  before_action :authorize_admin!
  # Eliminamos :show de la lista ya que no lo estamos usando
  before_action :set_user, only: %i[edit update destroy edit_password update_password]

  def index
    @users = User.all.order(created_at: :desc)
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      redirect_to users_path, notice: "Usuario creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    # Si el password viene vacío en el update normal, no lo actualizamos
    params_to_use = user_params.to_h
    if params_to_use[:password].blank?
      params_to_use.delete(:password)
      params_to_use.delete(:password_confirmation)
    end

    if @user.update(params_to_use)
      redirect_to users_path, notice: "Usuario actualizado correctamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @user == current_user
      redirect_to users_path, alert: "No puedes eliminarte a ti mismo."
    else
      @user.destroy
      redirect_to users_path, notice: "Usuario eliminado."
    end
  end

  def edit_password
  end

  def update_password
    if @user.update(password_params)
      redirect_to users_path, notice: "Contraseña de #{@user.email} actualizada correctamente."
    else
      render :edit_password, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation, :role)
  end

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
