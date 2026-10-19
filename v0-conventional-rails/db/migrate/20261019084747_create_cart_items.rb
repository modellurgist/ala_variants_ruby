class CreateCartItems < ActiveRecord::Migration[8.1]
  def change
    create_table :cart_items do |t|
      t.references :cart, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1
      t.boolean :gift_wrap, null: false, default: false
      t.boolean :saved_for_later, null: false, default: false
      t.datetime :removed_at

      t.timestamps
    end
    add_index :cart_items, [ :cart_id, :product_id ], unique: true
  end
end
