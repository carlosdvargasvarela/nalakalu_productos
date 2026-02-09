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

ActiveRecord::Schema[7.2].define(version: 2026_01_12_201019) do
  create_table "compatibilities", force: :cascade do |t|
    t.integer "variant_id", null: false
    t.integer "compatible_variant_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["compatible_variant_id"], name: "index_compatibilities_on_compatible_variant_id"
    t.index ["variant_id", "compatible_variant_id"], name: "index_compatibilities_on_variant_id_and_compatible_variant_id", unique: true
    t.index ["variant_id"], name: "index_compatibilities_on_variant_id"
  end

  create_table "product_variant_rules", force: :cascade do |t|
    t.integer "product_id", null: false
    t.integer "variant_type_id", null: false
    t.integer "position"
    t.boolean "required", default: true
    t.string "separator", default: "-"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_product_variant_rules_on_product_id"
    t.index ["variant_type_id"], name: "index_product_variant_rules_on_variant_type_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "name"
    t.string "base_code"
    t.text "description"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "providers", force: :cascade do |t|
    t.string "name"
    t.string "contact_name"
    t.string "email"
    t.string "phone"
    t.text "notes"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "role", default: "seller"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "variant_types", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
  end

  create_table "variants", force: :cascade do |t|
    t.integer "variant_type_id", null: false
    t.integer "provider_id", null: false
    t.string "name"
    t.string "code"
    t.string "provider_sku"
    t.decimal "cost"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider_id"], name: "index_variants_on_provider_id"
    t.index ["variant_type_id"], name: "index_variants_on_variant_type_id"
  end

  add_foreign_key "compatibilities", "variants"
  add_foreign_key "compatibilities", "variants", column: "compatible_variant_id"
  add_foreign_key "product_variant_rules", "products"
  add_foreign_key "product_variant_rules", "variant_types"
  add_foreign_key "variants", "providers"
  add_foreign_key "variants", "variant_types"
end
