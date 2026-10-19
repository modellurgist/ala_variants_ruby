class CartItemsController < ApplicationController
  before_action :set_cart_item, except: :create

  def create
    current_cart.add_product(Product.find(params[:product_id]))
    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = "Added to cart"
        render turbo_stream: turbo_stream.update("flash", partial: "layouts/flash")
      end
      format.html { redirect_back_or_to products_path, notice: "Added to cart" }
    end
  end

  def update
    @cart_item.update(quantity: params[:quantity])
  end

  def destroy
    @cart_item.remove!
  end

  def gift_wrap
    @cart_item.toggle!(:gift_wrap)
  end

  def save_for_later
    @cart_item.save_for_later!
    flash.now[:notice] = "Saved for later"
  end

  def move_to_cart
    @cart_item.move_to_cart!
    flash.now[:notice] = "Moved to cart"
  end

  def wishlist
    @wishlist_item = current_cart.toggle_wishlist(@cart_item.product)
    flash.now[:notice] = @wishlist_item.destroyed? ? "Removed from wishlist" : "Added to wishlist"
  end

  private
    def set_cart_item
      @cart_item = current_cart.cart_items.active.find(params[:id])
    end
end
