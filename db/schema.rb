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

ActiveRecord::Schema[7.2].define(version: 2026_04_15_142630) do
  create_table "code_settings", force: :cascade do |t|
    t.string "name", default: "Configuración General"
    t.integer "max_chars_per_line", default: 30
    t.integer "max_lines", default: 5
    t.string "default_separator", default: "-"
    t.boolean "show_stock_sala", default: true
    t.string "stock_sala_label", default: "STOCK DE SALA"
    t.boolean "use_prefixes", default: true
    t.integer "prefix_length", default: 3
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "compatibilities", force: :cascade do |t|
    t.integer "variant_id", null: false
    t.integer "compatible_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "compatible_type", default: "Variant"
    t.index ["compatible_id"], name: "index_compatibilities_on_compatible_id"
    t.index ["compatible_type", "compatible_id"], name: "index_compatibilities_on_compatible_type_and_compatible_id"
    t.index ["variant_id", "compatible_id", "compatible_type"], name: "index_compatibilities_unique_composite", unique: true
    t.index ["variant_id"], name: "index_compatibilities_on_variant_id"
  end

  create_table "families", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "family_variant_rules", force: :cascade do |t|
    t.integer "family_id", null: false
    t.integer "variant_type_id", null: false
    t.integer "position"
    t.boolean "required", default: true
    t.string "separator", default: "-"
    t.string "label"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["family_id"], name: "index_family_variant_rules_on_family_id"
    t.index ["variant_type_id"], name: "index_family_variant_rules_on_variant_type_id"
  end

  create_table "procurement_requirements", force: :cascade do |t|
    t.integer "supplier_item_id", null: false
    t.integer "purchase_order_item_id"
    t.string "origin_order_number", null: false
    t.string "origin_delivery_id"
    t.string "origin_product_name"
    t.decimal "quantity", precision: 10, scale: 4, null: false
    t.json "specifications", default: {}, null: false
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "origin_products", default: []
    t.integer "supply_rule_id"
    t.index ["origin_order_number"], name: "index_procurement_requirements_on_origin_order_number"
    t.index ["purchase_order_item_id"], name: "index_procurement_requirements_on_purchase_order_item_id"
    t.index ["status"], name: "index_procurement_requirements_on_status"
    t.index ["supplier_item_id", "origin_order_number"], name: "index_procurement_req_unique", unique: true
    t.index ["supplier_item_id"], name: "index_procurement_requirements_on_supplier_item_id"
    t.index ["supply_rule_id"], name: "index_procurement_requirements_on_supply_rule_id"
  end

  create_table "product_variant_rules", force: :cascade do |t|
    t.integer "product_id", null: false
    t.integer "variant_type_id", null: false
    t.integer "position"
    t.boolean "required", default: true
    t.string "separator", default: "-"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "label"
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
    t.integer "family_id"
    t.index ["family_id"], name: "index_products_on_family_id"
  end

  create_table "properties", force: :cascade do |t|
    t.string "name", null: false
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_properties_on_name", unique: true
  end

  create_table "property_values", force: :cascade do |t|
    t.integer "property_id", null: false
    t.string "value", null: false
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["property_id", "value"], name: "index_property_values_on_property_id_and_value", unique: true
    t.index ["property_id"], name: "index_property_values_on_property_id"
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
    t.string "category", default: "externo"
  end

  create_table "purchase_order_items", force: :cascade do |t|
    t.integer "purchase_order_id", null: false
    t.decimal "quantity"
    t.string "unit"
    t.decimal "unit_cost"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "description_override"
    t.integer "supplier_item_id", null: false
    t.json "specifications", default: {}, null: false
    t.index ["purchase_order_id"], name: "index_purchase_order_items_on_purchase_order_id"
    t.index ["supplier_item_id"], name: "index_purchase_order_items_on_supplier_item_id"
  end

  create_table "purchase_orders", force: :cascade do |t|
    t.integer "provider_id", null: false
    t.string "number"
    t.date "issued_date"
    t.date "delivery_deadline"
    t.string "status"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "sent_at"
    t.index ["provider_id"], name: "index_purchase_orders_on_provider_id"
  end

  create_table "supplier_item_properties", force: :cascade do |t|
    t.integer "supplier_item_id", null: false
    t.integer "property_value_id"
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "label"
    t.string "spec_type", default: "property"
    t.index ["property_value_id"], name: "index_supplier_item_properties_on_property_value_id"
    t.index ["supplier_item_id", "property_value_id"], name: "index_supplier_item_props_unique", unique: true
    t.index ["supplier_item_id"], name: "index_supplier_item_properties_on_supplier_item_id"
  end

  create_table "supplier_items", force: :cascade do |t|
    t.integer "provider_id", null: false
    t.string "name", null: false
    t.string "sku"
    t.string "unit", default: "unidad"
    t.decimal "default_cost", precision: 15, scale: 2
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider_id", "sku"], name: "index_supplier_items_on_provider_id_and_sku", unique: true, where: "sku IS NOT NULL"
    t.index ["provider_id"], name: "index_supplier_items_on_provider_id"
  end

  create_table "supply_rule_quantities", force: :cascade do |t|
    t.integer "supply_rule_id", null: false
    t.integer "product_id", null: false
    t.decimal "quantity_needed", precision: 10, scale: 4, default: "1.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_supply_rule_quantities_on_product_id"
    t.index ["supply_rule_id", "product_id"], name: "index_supply_rule_quantities_on_supply_rule_id_and_product_id", unique: true
    t.index ["supply_rule_id"], name: "index_supply_rule_quantities_on_supply_rule_id"
  end

  create_table "supply_rules", force: :cascade do |t|
    t.integer "product_id"
    t.integer "variant_type_id", null: false
    t.integer "variant_id"
    t.integer "supplier_item_id", null: false
    t.decimal "quantity_needed", precision: 10, scale: 4, default: "1.0", null: false
    t.string "rule_type", default: "individual", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "variant_id", "supplier_item_id"], name: "index_supply_rules_unique_composite", unique: true
    t.index ["product_id"], name: "index_supply_rules_on_product_id"
    t.index ["supplier_item_id"], name: "index_supply_rules_on_supplier_item_id"
    t.index ["variant_id"], name: "index_supply_rules_on_variant_id"
    t.index ["variant_type_id"], name: "index_supply_rules_on_variant_type_id"
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
    t.string "microsoft_provider"
    t.string "microsoft_uid"
    t.string "microsoft_token"
    t.string "microsoft_refresh_token"
    t.datetime "microsoft_token_expires_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "variant_types", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.boolean "active", default: true, null: false
    t.integer "position", default: 0
    t.string "procurement_strategy", default: "individual", null: false
  end

  create_table "variants", force: :cascade do |t|
    t.integer "variant_type_id", null: false
    t.string "name"
    t.string "code"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "display_name"
    t.text "technical_description"
    t.index ["variant_type_id"], name: "index_variants_on_variant_type_id"
  end

  add_foreign_key "compatibilities", "variants"
  add_foreign_key "family_variant_rules", "families"
  add_foreign_key "family_variant_rules", "variant_types"
  add_foreign_key "procurement_requirements", "purchase_order_items"
  add_foreign_key "procurement_requirements", "supplier_items"
  add_foreign_key "product_variant_rules", "products"
  add_foreign_key "product_variant_rules", "variant_types"
  add_foreign_key "products", "families"
  add_foreign_key "property_values", "properties"
  add_foreign_key "purchase_order_items", "purchase_orders"
  add_foreign_key "purchase_order_items", "supplier_items"
  add_foreign_key "purchase_orders", "providers"
  add_foreign_key "supplier_item_properties", "property_values"
  add_foreign_key "supplier_item_properties", "supplier_items"
  add_foreign_key "supplier_items", "providers"
  add_foreign_key "supply_rule_quantities", "products"
  add_foreign_key "supply_rule_quantities", "supply_rules"
  add_foreign_key "supply_rules", "products"
  add_foreign_key "supply_rules", "supplier_items"
  add_foreign_key "supply_rules", "variant_types"
  add_foreign_key "supply_rules", "variants"
  add_foreign_key "variants", "variant_types"
end
