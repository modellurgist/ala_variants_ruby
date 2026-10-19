class CreateCarts < ActiveRecord::Migration[8.1]
  def change
    create_table :carts do |t|
      t.string :status, null: false, default: "open"
      t.string :kind, null: false, default: "storefront"
      t.string :promo_code
      t.string :shipping_method, null: false, default: "standard"

      t.timestamps
    end
  end
end
