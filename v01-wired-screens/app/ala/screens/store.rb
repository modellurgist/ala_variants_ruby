module Screens
  # The store's calibration: the numbers and words that make this *this* shop, in one place at the
  # composition so every domain abstraction below stays generic. Screens read it and pass its values
  # down as configuration; nothing below reaches up to it.
  module Store
    RATES = {
      standard: { label: "Standard (5–7 days)", cost: 599, free_above: 5000 },
      express: { label: "Express (2–3 days)", cost: 1299, free_above: nil },
      overnight: { label: "Overnight", cost: 2499, free_above: nil }
    }.freeze

    GIFT_WRAP_CENTS = 299
    PROMO_CODES = { "SAVE10" => 10, "SAVE20" => 20, "HALF" => 50 }.freeze
    VOLUME_TIERS = [ [ 200_000, 10, "10% volume discount" ], [ 50_000, 5, "5% volume discount" ] ].freeze
    LOW_STOCK_AT = 5
    CURRENCY = "usd"
    UNDO_WINDOW = 5.seconds

    STOCK_LABELS = { in_stock: "%{n} in stock", low_stock: "Only %{n} left!", out_of_stock: "Out of stock" }.freeze

    SUMMARY_TEXTS = { items: "Items", subtotal: "Subtotal", shipping: "Shipping", free: "Free", total: "Total" }.freeze

    PRODUCT_FORM = {
      fields: [ [ :name, :text, "Name" ], [ :description, :text, "Description" ], [ :amount, :number, "Amount (cents)" ],
                [ :stock, :number, "Stock" ], [ :thumbnail, :text, "Thumbnail URL" ] ],
      subtitle: "Use this form to manage product records in your database.",
      submit: "Save Product"
    }.freeze
  end
end
