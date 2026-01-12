json.extract! product, :id, :name, :base_code, :active, :created_at, :updated_at
json.url product_url(product, format: :json)
