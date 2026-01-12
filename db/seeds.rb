# Crear Proveedores
p1 = Provider.create!(name: "Textiles del Sur", contact_name: "Juan Pérez", email: "juan@textiles.com")
p2 = Provider.create!(name: "Maderas Finas", contact_name: "Ana García", email: "ana@maderas.com")

# Crear Tipos de Variante
t_tela = VariantType.create!(name: "Tela")
t_madera = VariantType.create!(name: "Color de Madera")

# Crear Variantes
Variant.create!(variant_type: t_tela, provider: p1, name: "Lino Gris", code: "LG")
Variant.create!(variant_type: t_tela, provider: p1, name: "Cuero Negro", code: "CN")
Variant.create!(variant_type: t_madera, provider: p2, name: "Roble", code: "RB")
Variant.create!(variant_type: t_madera, provider: p2, name: "Nogal", code: "NG")

puts "Seeds cargados exitosamente!"