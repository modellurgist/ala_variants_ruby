class CreateStoreTables < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.text :description
      t.integer :amount, null: false
      t.integer :stock, null: false, default: 0
      t.text :thumbnail
      t.timestamps
    end

    create_table :carts do |t|
      t.string :status, null: false, default: "open"
      t.timestamps
    end

    # The storefront cart's lines, and the portal's order lines: one table, the shared "lines" abstraction.
    create_table :cart_items do |t|
      t.references :cart, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1
      t.boolean :gift_wrapped, null: false, default: false
      t.datetime :removed_at
      t.timestamps
    end
    add_index :cart_items, [ :cart_id, :product_id ], unique: true

    # Each feature below keeps its own data against the cart's identity.
    create_table :saved_items do |t|
      t.references :cart, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1
      t.timestamps
    end
    add_index :saved_items, [ :cart_id, :product_id ], unique: true

    create_table :wishlist_items do |t|
      t.references :cart, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.timestamps
    end
    add_index :wishlist_items, [ :cart_id, :product_id ], unique: true

    create_table :cart_pricing_choices do |t|
      t.references :cart, null: false, foreign_key: true, index: { unique: true }
      t.string :promo_code
      t.string :shipping_method
      t.timestamps
    end

    create_table :checkouts do |t|
      t.references :cart, null: false, foreign_key: true, index: { unique: true }
      t.string :step, null: false, default: "address"
      t.string :name
      t.string :line1
      t.string :city
      t.string :postal_code
      t.string :payment_reference
      t.timestamps
    end

    create_table :order_submissions do |t|
      t.references :cart, null: false, foreign_key: true, index: { unique: true }
      t.string :step, null: false, default: "lines"
      t.string :po_number
      t.text :notes
      t.timestamps
    end

    create_table :orders do |t|
      t.references :cart, null: false, foreign_key: true
      t.string :po_number
      t.timestamps
    end
  end
end
