class PromoCodesController < ApplicationController
  def update
    if current_cart.apply_promo_code(params[:code])
      flash.now[:notice] = "Promo applied!"
    else
      @error = "Invalid promo code"
      flash.now[:alert] = @error
    end
  end
end
