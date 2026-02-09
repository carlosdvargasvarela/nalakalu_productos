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

seller2 = User.create!(
  email: "vendedor2@nalakalu.com",
  password: "123456",
  password_confirmation: "123456",
  role: "seller"
)
puts "✅ Vendedor 2 creado: #{seller2.email} / 123456"

puts "\n🏭 Creando Proveedores..."

p1 = Provider.create!(
  name: "Textiles del Sur",
  contact_name: "Juan Pérez",
  email: "juan@textiles.com",
  phone: "+506 2222-3333",
  active: true
)

p2 = Provider.create!(
  name: "Maderas Finas",
  contact_name: "Ana García",
  email: "ana@maderas.com",
  phone: "+506 2444-5555",
  active: true
)

p3 = Provider.create!(
  name: "Herrajes Premium",
  contact_name: "Carlos Rojas",
  email: "carlos@herrajes.com",
  phone: "+506 2666-7777",
  active: true
)

puts "✅ #{Provider.count} proveedores creados"

puts "\n📦 Creando Tipos de Variante..."

t_tela = VariantType.create!(name: "Tela", description: "Tipo de tapizado")
t_madera = VariantType.create!(name: "Color de Madera", description: "Acabado de madera")
t_patas = VariantType.create!(name: "Tipo de Patas", description: "Material y estilo de patas")
t_tamano = VariantType.create!(name: "Tamaño", description: "Dimensiones del mueble")

puts "✅ #{VariantType.count} tipos de variante creados"

puts "\n🎨 Creando Variantes..."

# Telas
v_lino_gris = Variant.create!(
  variant_type: t_tela,
  provider: p1,
  name: "Lino Gris",
  code: "LG",
  provider_sku: "TEX-LG-001",
  cost: 45.00,
  active: true
)

v_cuero_negro = Variant.create!(
  variant_type: t_tela,
  provider: p1,
  name: "Cuero Negro",
  code: "CN",
  provider_sku: "TEX-CN-002",
  cost: 120.00,
  active: true
)

v_terciopelo_azul = Variant.create!(
  variant_type: t_tela,
  provider: p1,
  name: "Terciopelo Azul",
  code: "TA",
  provider_sku: "TEX-TA-003",
  cost: 85.00,
  active: true
)

# Maderas
v_roble = Variant.create!(
  variant_type: t_madera,
  provider: p2,
  name: "Roble Natural",
  code: "RB",
  provider_sku: "MAD-RB-001",
  cost: 60.00,
  active: true
)

v_nogal = Variant.create!(
  variant_type: t_madera,
  provider: p2,
  name: "Nogal Oscuro",
  code: "NG",
  provider_sku: "MAD-NG-002",
  cost: 75.00,
  active: true
)

v_cerezo = Variant.create!(
  variant_type: t_madera,
  provider: p2,
  name: "Cerezo",
  code: "CR",
  provider_sku: "MAD-CR-003",
  cost: 70.00,
  active: true
)

# Patas
v_patas_madera = Variant.create!(
  variant_type: t_patas,
  provider: p3,
  name: "Patas de Madera",
  code: "PM",
  provider_sku: "HER-PM-001",
  cost: 30.00,
  active: true
)

v_patas_metal = Variant.create!(
  variant_type: t_patas,
  provider: p3,
  name: "Patas de Metal Negro",
  code: "PMN",
  provider_sku: "HER-PMN-002",
  cost: 40.00,
  active: true
)

# Tamaños
v_individual = Variant.create!(
  variant_type: t_tamano,
  provider: p1,
  name: "Individual (1 plaza)",
  code: "1P",
  provider_sku: "TAM-1P",
  cost: 0,
  active: true
)

v_doble = Variant.create!(
  variant_type: t_tamano,
  provider: p1,
  name: "Doble (2 plazas)",
  code: "2P",
  provider_sku: "TAM-2P",
  cost: 0,
  active: true
)

v_triple = Variant.create!(
  variant_type: t_tamano,
  provider: p1,
  name: "Triple (3 plazas)",
  code: "3P",
  provider_sku: "TAM-3P",
  cost: 0,
  active: true
)

puts "✅ #{Variant.count} variantes creadas"

puts "\n🔗 Configurando Compatibilidades..."

# Regla: Terciopelo Azul solo es compatible con Patas de Metal
v_terciopelo_azul.compatible_variants << v_patas_metal

# Regla: Cuero Negro es compatible con cualquier pata de madera
v_cuero_negro.compatible_variants << v_patas_madera

# Regla: Lino Gris es compatible con ambas patas
v_lino_gris.compatible_variants << v_patas_madera
v_lino_gris.compatible_variants << v_patas_metal

puts "✅ Compatibilidades configuradas"

puts "\n🛋️ Creando Productos Base..."

# Producto 1: Sofá Milano
producto_milano = Product.create!(
  name: "Sofá Milano",
  base_code: "MIL",
  description: "Sofá moderno estilo italiano",
  active: true
)

producto_milano.product_variant_rules.create!([
  { variant_type: t_tamano, position: 1, required: true, separator: "-" },
  { variant_type: t_tela, position: 2, required: true, separator: "-" },
  { variant_type: t_patas, position: 3, required: false, separator: "/" }
])

# Producto 2: Mesa Nórdica
producto_mesa = Product.create!(
  name: "Mesa Nórdica",
  base_code: "NOR",
  description: "Mesa de comedor estilo escandinavo",
  active: true
)

producto_mesa.product_variant_rules.create!([
  { variant_type: t_madera, position: 1, required: true, separator: "-" },
  { variant_type: t_tamano, position: 2, required: true, separator: "" }
])

# Producto 3: Silla Clásica
producto_silla = Product.create!(
  name: "Silla Clásica",
  base_code: "CLA",
  description: "Silla de comedor clásica",
  active: true
)

producto_silla.product_variant_rules.create!([
  { variant_type: t_tela, position: 1, required: true, separator: "-" },
  { variant_type: t_madera, position: 2, required: true, separator: "/" }
])

puts "✅ #{Product.count} productos creados"

puts "\n" + "="*60
puts "🎉 SEEDS COMPLETADOS EXITOSAMENTE"
puts "="*60
puts "\n📧 CUENTAS CREADAS:"
puts "   Admin:      admin@nalakalu.com / 123456"
puts "   Vendedor 1: vendedor1@nalakalu.com / 123456"
puts "   Vendedor 2: vendedor2@nalakalu.com / 123456"
puts "\n📊 DATOS:"
puts "   #{User.count} usuarios"
puts "   #{Provider.count} proveedores"
puts "   #{VariantType.count} tipos de variante"
puts "   #{Variant.count} variantes"
puts "   #{Compatibility.count} reglas de compatibilidad"
puts "   #{Product.count} productos"
puts "   #{ProductVariantRule.count} reglas de producto"
puts "\n💡 EJEMPLOS DE CÓDIGOS:"
puts "   Sofá Milano 2 plazas + Lino Gris + Patas Metal: MIL-2P-LG/PMN"
puts "   Mesa Nórdica Roble 3 plazas: NOR-RB3P"
puts "   Silla Clásica Cuero Negro + Nogal: CLA-CN/NG"
puts "="*60