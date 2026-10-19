class CreateCheckouts < ActiveRecord::Migration[8.1]
  def change
    create_table :checkouts do |t|
      t.references :cart, null: false, foreign_key: true, index: { unique: true }
      t.string :name
      t.string :address
      t.string :city
      t.string :postal_code
      t.string :payment_status

      t.timestamps
    end
  end
end
