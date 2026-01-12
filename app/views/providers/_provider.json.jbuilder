json.extract! provider, :id, :name, :contact_name, :email, :phone, :notes, :active, :created_at, :updated_at
json.url provider_url(provider, format: :json)
