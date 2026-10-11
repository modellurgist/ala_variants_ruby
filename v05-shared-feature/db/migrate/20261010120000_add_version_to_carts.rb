class AddVersionToCarts < ActiveRecord::Migration[8.1]
  def change
    add_column :carts, :version, :integer, null: false, default: 0
  end
end
