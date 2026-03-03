# Limpiar datos existentes (solo en desarrollo)
if Rails.env.development?
  puts "🧹 Limpiando datos existentes..."
  Compatibility.destroy_all
  ProductVariantRule.destroy_all
  Product.destroy_all
  Variant.destroy_all
  VariantType.destroy_all
  Provider.destroy_all
  User.destroy_all
end

puts "👤 Creando usuarios..."

# Usuario Administrador
admin = User.create!(
  email: "admin@nalakalu.com",
  password: "123456",
  password_confirmation: "123456",
  role: "admin"
)
puts "✅ Admin creado: #{admin.email} / 123456"

# Usuarios Vendedores
seller1 = User.create!(
  email: "vendedor1@nalakalu.com",
  password: "123456",
  password_confirmation: "123456",
  role: "seller"
)
puts "✅ Vendedor 1 creado: #{seller1.email} / 123456"
