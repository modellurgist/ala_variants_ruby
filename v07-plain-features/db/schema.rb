# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_05_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "cart_items", force: :cascade do |t|
    t.bigint "cart_id", null: false
    t.bigint "product_id", null: false
    t.integer "quantity", default: 1, null: false
    t.boolean "gift_wrapped", default: false, null: false
    t.datetime "removed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cart_id", "product_id"], name: "index_cart_items_on_cart_id_and_product_id", unique: true
    t.index ["cart_id"], name: "index_cart_items_on_cart_id"
    t.index ["product_id"], name: "index_cart_items_on_product_id"
  end

  create_table "cart_pricing_choices", force: :cascade do |t|
    t.bigint "cart_id", null: false
    t.string "promo_code"
    t.string "shipping_method"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cart_id"], name: "index_cart_pricing_choices_on_cart_id", unique: true
  end

  create_table "carts", force: :cascade do |t|
    t.string "status", default: "open", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "checkouts", force: :cascade do |t|
    t.bigint "cart_id", null: false
    t.string "step", default: "address", null: false
    t.string "name"
    t.string "line1"
    t.string "city"
    t.string "postal_code"
    t.string "payment_reference"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cart_id"], name: "index_checkouts_on_cart_id", unique: true
  end

  create_table "order_submissions", force: :cascade do |t|
    t.bigint "cart_id", null: false
    t.string "step", default: "lines", null: false
    t.string "po_number"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cart_id"], name: "index_order_submissions_on_cart_id", unique: true
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "cart_id", null: false
    t.string "po_number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cart_id"], name: "index_orders_on_cart_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.integer "amount", null: false
    t.integer "stock", default: 0, null: false
    t.text "thumbnail"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "saved_items", force: :cascade do |t|
    t.bigint "cart_id", null: false
    t.bigint "product_id", null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cart_id", "product_id"], name: "index_saved_items_on_cart_id_and_product_id", unique: true
    t.index ["cart_id"], name: "index_saved_items_on_cart_id"
    t.index ["product_id"], name: "index_saved_items_on_product_id"
  end

  create_table "wishlist_items", force: :cascade do |t|
    t.bigint "cart_id", null: false
    t.bigint "product_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cart_id", "product_id"], name: "index_wishlist_items_on_cart_id_and_product_id", unique: true
    t.index ["cart_id"], name: "index_wishlist_items_on_cart_id"
    t.index ["product_id"], name: "index_wishlist_items_on_product_id"
  end

  add_foreign_key "cart_items", "carts"
  add_foreign_key "cart_items", "products"
  add_foreign_key "cart_pricing_choices", "carts"
  add_foreign_key "checkouts", "carts"
  add_foreign_key "order_submissions", "carts"
  add_foreign_key "orders", "carts"
  add_foreign_key "saved_items", "carts"
  add_foreign_key "saved_items", "products"
  add_foreign_key "wishlist_items", "carts"
  add_foreign_key "wishlist_items", "products"
end
