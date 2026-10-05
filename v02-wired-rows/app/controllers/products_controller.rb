class ProductsController < ApplicationController
  def index
    screen.input_port(:load).send_event
    @rows = screen.rows
  end

  def show
    screen.input_port(:show).push(params[:id])
    @row = screen.row
  end

  def new
    screen.input_port(:new).send_event
    @form = screen.form
  end

  def edit
    screen.input_port(:edit).push(params[:id])
    @form = screen.form
  end

  def validate
    screen.input_port(:validate).push(id: params[:id].presence, attrs: product_params)
    @form = screen.form
    render turbo_stream: turbo_stream.replace(helpers.dom_id(@form, :form), partial: "products/form", locals: { form: @form })
  end

  def create
    screen.input_port(:save).push(id: nil, attrs: product_params)
    saved_or_form(products_path, "New Product")
  end

  def update
    screen.input_port(:save).push(id: params[:id], attrs: product_params)
    saved_or_form(product_path(params[:id]), "Edit Product")
  end

  def destroy
    screen.input_port(:delete).push(params[:id])
    redirect_to products_path, notice: "Product deleted"
  end

  def add_to_cart
    screen.input_port(:add_to_cart).push(params[:id])
    redirect_to products_path, notice: screen.notices.join(" ")
  end

  private

  def screen = @screen ||= Screens::Catalog.new(cart_id:)
  def product_params = params.expect(product: [ :name, :description, :amount, :stock, :thumbnail ])

  def saved_or_form(path, title)
    if screen.saved
      redirect_to path, notice: screen.notices.join(" ")
    else
      @form = screen.form
      @title = title
      render :form_again, status: :unprocessable_content
    end
  end
end
