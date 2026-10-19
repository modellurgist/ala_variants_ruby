class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.references :cart, null: false, foreign_key: true, index: { unique: true }
      t.string :po_number
      t.integer :total_cents, null: false

      t.timestamps
    end
  end
end
