class ProductsController < ApplicationController
  def index
    screen.load
    @rows = screen.rows
    @feed = screen.feed
  end

  def show
    screen.show(params[:id])
    @row = screen.row
    @feed = screen.feed
  end

  def new
    screen.new
    @form = screen.form
  end

  def edit
    screen.edit(params[:id])
    @form = screen.form
  end

  def validate
    screen.validate(id: params[:id].presence, attrs: product_params)
    @form = screen.form
    render turbo_stream: turbo_stream.replace(helpers.dom_id(@form, :form), partial: "products/form", locals: { form: @form })
  end

  def create
    screen.save(id: nil, attrs: product_params)
    saved_or_form(products_path, "New Product")
  end

  def update
    screen.save(id: params[:id], attrs: product_params)
    saved_or_form(product_path(params[:id]), "Edit Product")
  end

  def destroy
    screen.delete(params[:id])
    redirect_to products_path, notice: "Product deleted"
  end

  def add_to_cart
    screen.add_to_cart(params[:id])
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
