module CartsHelper
  def cart_tab_count(cart, tab)
    case tab
    when "items" then cart.items.sum(:quantity)
    when "saved" then cart.saved_items.count
    else cart.wishlist_items.count
    end
  end
end
