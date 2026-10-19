module ApplicationHelper
  def money(cents)
    number_to_currency(cents / 100.0)
  end

  def stock_label(product)
    case product.stock_status
    when :out_of_stock then "Out of stock"
    when :low_stock then "Low stock (#{product.stock} left)"
    else "In stock"
    end
  end

  def stock_badge(product)
    colors = { in_stock: "bg-emerald-100 text-emerald-800", low_stock: "bg-amber-100 text-amber-800", out_of_stock: "bg-red-100 text-red-700" }
    tag.span stock_label(product), class: "rounded-full px-2 py-0.5 text-xs font-medium #{colors[product.stock_status]}"
  end
end
