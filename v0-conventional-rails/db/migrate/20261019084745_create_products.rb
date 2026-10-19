class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.text :description
      t.integer :amount, null: false
      t.integer :stock, null: false, default: 0
      t.string :thumbnail

      t.timestamps
    end
  end
end
