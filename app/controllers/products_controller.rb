class ProductsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!
  before_action :set_product, only: %i[show edit update destroy]

  def index
    @products = Product.all.includes(:product_variant_rules)
  end

  def show
  end

  def new
    @product = Product.new
  end

  def edit
  end

  def create
    @product = Product.new(product_params)

    respond_to do |format|
      if @product.save
        format.html { redirect_to @product, notice: "Producto creado exitosamente." }
        format.json { render :show, status: :created, location: @product }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @product.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @product.update(product_params)
        format.html { redirect_to @product, notice: "Producto actualizado exitosamente." }
        format.json { render :show, status: :ok, location: @product }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @product.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @product.destroy!

    respond_to do |format|
      format.html { redirect_to products_path, status: :see_other, notice: "Producto eliminado." }
      format.json { head :no_content }
    end
  end

  def import
    unless params[:file].present?
      redirect_to products_path, alert: "Selecciona un archivo CSV"
      return
    end

    file = params[:file]
    tmp_path = Rails.root.join("tmp", "import_products_#{Time.now.to_i}.csv")

    # Copiar archivo de forma segura
    FileUtils.cp(file.tempfile.path, tmp_path)

    # Encolar job
    ImportProductsJob.perform_later(tmp_path.to_s, current_user.id)

    redirect_to products_path, notice: "Importación iniciada. Revisa los logs."
  end

  private

  def set_product
    @product = Product.find(params[:id])
  end

  def product_params
    params.require(:product).permit(
      :name,
      :base_code,
      :description,
      :active,
      product_variant_rules_attributes: [
        :id,
        :variant_type_id,
        :position,
        :required,
        :separator,
        :label,
        :_destroy
      ]
    )
  end
end
