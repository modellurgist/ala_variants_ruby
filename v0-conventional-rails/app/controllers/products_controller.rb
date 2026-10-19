class ProductsController < ApplicationController
  before_action :set_product, only: %i[ show edit update destroy ]

  def index
    @products = Product.order(:created_at, :id)
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
        format.html { redirect_to products_path, notice: "Product created successfully" }
        format.turbo_stream { flash.now[:notice] = "Product created successfully" }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @product.update(product_params)
        format.html { redirect_to @product, notice: "Product updated successfully" }
        format.turbo_stream { flash.now[:notice] = "Product updated successfully" }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @product.destroy!
    redirect_to products_path, notice: "Product deleted", status: :see_other
  end

  def validate
    @product = params[:id] ? Product.find(params[:id]) : Product.new
    @product.assign_attributes(product_params)
    @product.validate
  end

  private
    def set_product
      @product = Product.find(params.expect(:id))
    end

    def product_params
      params.expect(product: [ :name, :description, :amount, :stock, :thumbnail ])
    end
end
