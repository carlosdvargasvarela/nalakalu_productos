# Qué mirar al revisar cada tipo de registro: verificaciones automáticas, guía en lenguaje llano y motivos rápidos.
class ReviewGuide
  Check = Struct.new(:level, :text, :hint) # level: :ok, :bad, :warn, :info

  GUIDE = {
    "Product" => {
      what: "Lo que se vende, por ejemplo una mesa de comedor. En Odoo será un «producto» con su categoría (la familia), su precio y sus atributos (los tipos de variante).",
      look: ["El nombre es claro y no tiene errores.", "El código base es correcto y no se repite.", "Está en la familia correcta.", "Tiene precio de venta.",
        "En cada tipo de variante solo están las opciones que de verdad se ofrecen para este producto (por ejemplo, solo las telas que existen para esa silla)."]
    },
    "Variant" => {
      what: "Una opción concreta, por ejemplo la tela «Lino gris». Pertenece a un tipo (Telas). En Odoo será un «valor de atributo».",
      look: ["El nombre no tiene errores ni está repetido dentro de su tipo.", "Está en el tipo correcto.", "El nombre comercial es el que vería el cliente.",
        "Si su tipo se compra con código de proveedor propio (como los textiles), tiene su pieza vinculada."]
    },
    "VariantType" => {
      what: "Un grupo de opciones del mismo estilo: Telas, Maderas, Piedras… En Odoo será un «atributo».",
      look: ["El nombre es claro.", "Todas sus variantes realmente van juntas. Si mezcla cosas distintas, usa Reorganizar para dividirlo; si hay dos tipos casi iguales, para unirlos.",
        "La marca «código de proveedor propio» está bien puesta (sí para textiles; no para materiales que dependen del producto)."]
    },
    "Family" => {
      what: "Un grupo de productos parecidos, por ejemplo «Mesas de comedor». Define qué tipos de variante usan. En Odoo será una «categoría de producto».",
      look: ["El nombre es claro.", "Todos sus productos pertenecen ahí (y no falta ninguno).", "Su estructura de código es correcta.",
        "No hay otra familia casi igual: si la hay, usa Reorganizar → Unir."]
    },
    "Provider" => {
      what: "A quién se le compra. En Odoo será un contacto de tipo proveedor.",
      look: ["El nombre es exactamente el que tendrá en Odoo (así se enlazan sus piezas).", "Tiene datos de contacto.", "La categoría (interno/externo) es correcta.", "No está repetido."]
    },
    "SupplierItem" => {
      what: "Lo que se compra a un proveedor, con su código y costo, y en qué productos o variantes se usa. En Odoo será la «información del proveedor» de un producto.",
      look: ["El código y el costo son correctos.", "Está vinculada a lo correcto: «solo variante» para cosas como un textil que sirve en cualquier producto; «producto + variante» cuando depende de ambos.",
        "Si la pieza cambia según la variante (sobre en piedra A, B o C), duplícala por variante."]
    }
  }.freeze

  REASONS = {
    "Product" => ["Falta el precio", "Nombre confuso o con errores", "Código incorrecto", "Familia incorrecta", "Faltan variantes", "Sobran variantes", "Duplicado"],
    "Variant" => ["Nombre con errores", "Tipo incorrecto", "Falta el código", "Duplicada", "Falta la pieza de proveedor"],
    "VariantType" => ["Nombre confuso", "Mezcla variantes distintas (dividir)", "Duplicado (unir)", "Falta marcar código propio"],
    "Family" => ["Nombre confuso", "Faltan productos", "Sobran productos", "Estructura de código incorrecta", "Duplicada (unir)"],
    "Provider" => ["Nombre distinto al de Odoo", "Falta contacto", "Categoría incorrecta", "Duplicado"],
    "SupplierItem" => ["Falta el código", "Falta el costo", "Costo incorrecto", "Mal vinculada", "Falta duplicar por variante"]
  }.freeze

  def self.guide(record) = GUIDE.fetch(record.class.name)
  def self.reasons(record) = REASONS.fetch(record.class.name)
  def self.checks(record) = new.public_send("checks_#{record.class.name.underscore}", record)

  def ok(text) = Check.new(:ok, text)
  def bad(text, hint) = Check.new(:bad, text, hint)
  def warn(text, hint) = Check.new(:warn, text, hint)
  def info(text) = Check.new(:info, text)

  def pl(n, one, many = "#{one}s") = (n == 1) ? "1 #{one}" : "#{n} #{many}"

  def money(n) = ActionController::Base.helpers.number_to_currency(n, unit: "₡", format: "%u%n")

  def checks_product(p)
    rules = p.product_variant_rules.includes(:variant_type).to_a
    out = []
    out << (p.family ? ok("Está en la familia «#{p.family.name}»") : bad("No tiene familia", "La familia agrupa productos parecidos. Asígnala desde Editar o con Reorganizar en la familia."))
    out << (p.list_price ? ok("Precio de venta: #{money(p.list_price)}") : bad("Sin precio de venta", "Odoo lo necesita para vender. Escríbelo en la lista (columna Precio) o súbelo con «Cargar precios»."))
    out << (Product.where(base_code: p.base_code).where.not(id: p.id).exists? ? bad("El código base «#{p.base_code}» está repetido", "Cada producto debe tener un código único.") : ok("Código base único: #{p.base_code}"))
    if rules.empty?
      out << warn("No tiene estructura de código", "Está bien solo si este producto no tiene opciones (telas, maderas…). Si sí las tiene, define su estructura desde Editar.")
    else
      out << ok("Estructura de código: #{rules.map { _1.label.presence || _1.variant_type.name }.to_sentence}")
      empty = rules.select { |r| !Compatibility.where(compatible_type: "ProductVariantRule", compatible_id: r.id).exists? }
      empty.each { |r| out << bad("«#{r.variant_type.name}» no tiene ninguna variante permitida", "Se crearía un atributo vacío en Odoo. Elige las variantes o quita ese paso.") }
    end
    out << info(p.supplier_links.count.zero? ? "Sin piezas de proveedor vinculadas" : "#{pl(p.supplier_links.count, "pieza")} de proveedor vinculadas")
    out << info("Está inactivo: se exporta como no activo.") unless p.active
    out
  end

  def checks_variant(v)
    out = []
    dup = Variant.where(variant_type_id: v.variant_type_id).where.not(id: v.id).select { _1.seller_name.to_s.squish.downcase == v.seller_name.to_s.squish.downcase }
    out << (dup.any? ? bad("Hay otra variante con el mismo nombre en «#{v.variant_type.name}»", "Elimina o renombra una; Odoo no permite dos valores iguales en un atributo.") : ok("Nombre único dentro de «#{v.variant_type.name}»"))
    out << ((v.name.to_s + v.display_name.to_s).include?(",") ? bad("El nombre tiene una coma", "La coma rompe la importación a Odoo. Quítala.") : ok("Nombre sin caracteres problemáticos"))
    n = v.compatible_product_ids.size
    out << (n.zero? ? warn("No está disponible en ningún producto", "Si debería usarse, agrégala a las reglas de los productos; si no, quizá sobra.") : ok("Disponible en #{pl(n, "producto")}"))
    if v.variant_type.own_supplier_code
      out << (v.supplier_links.any? ? ok("Tiene su pieza de proveedor") : bad("Falta su pieza de proveedor", "Este tipo se compra con código propio. Crea o vincula la pieza (Piezas de proveedor → Dónde se usa)."))
    end
    out << info("Código CRM: #{v.code.presence || "—"}")
    out
  end

  def checks_variant_type(t)
    vs = t.variants.to_a
    out = []
    out << (vs.any? ? ok("Tiene #{pl(vs.size, "variante")}") : bad("No tiene variantes", "Un atributo sin valores no sirve en Odoo. Agrégale variantes o elimínalo."))
    out << (t.own_supplier_code ? info("Sus variantes tienen código de proveedor propio") : info("Sus variantes dependen del producto (sin código propio)"))
    if t.own_supplier_code && vs.any?
      missing = vs.count { |v| v.supplier_links.none? }
      out << (missing.zero? ? ok("Todas sus variantes tienen pieza de proveedor") : bad("#{pl(missing, "variante")} sin pieza de proveedor", "Abre Calidad → «Variantes de tipos con código propio sin pieza» para ver cuáles."))
    end
    used = t.product_variant_rules.count
    out << (used.zero? ? warn("Ningún producto lo usa", "Si no se usa, no aparecerá como atributo en Odoo.") : ok("Lo usan #{pl(used, "producto")}"))
    out
  end

  def checks_family(f)
    prods = f.products.to_a
    out = []
    out << (prods.any? ? ok("Tiene #{pl(prods.size, "producto")}") : warn("No tiene productos", "Una familia vacía crea una categoría vacía en Odoo. Asígnale productos o ocúltala."))
    out << (f.family_variant_rules.any? ? ok("Estructura de código: #{f.family_variant_rules.includes(:variant_type).map { _1.label.presence || _1.variant_type.name }.to_sentence}") : warn("No define estructura de código", "Está bien si sus productos no usan variantes."))
    out << (f.description.present? ? ok("Tiene descripción") : info("Sin descripción (opcional)"))
    out
  end

  def checks_provider(p)
    out = []
    contact = [p.contact_name, p.email, p.phone].compact_blank
    out << (contact.any? ? ok("Contacto: #{contact.join(" · ")}") : warn("Sin datos de contacto", "Agrega al menos correo o teléfono."))
    n = p.supplier_items.count
    out << (n.zero? ? warn("No tiene piezas", "Si no se le compra nada, quizá sobra.") : ok("Tiene #{pl(n, "pieza")}"))
    out << info("Categoría: #{p.category}")
    out
  end

  def checks_supplier_item(i)
    out = []
    out << (i.sku.present? ? ok("Código del proveedor: #{i.sku}") : bad("Sin código del proveedor", "Es lo que identifica la pieza al comprar. Escríbelo en la lista (columna Código)."))
    out << (i.default_cost ? ok("Costo: #{money(i.default_cost)} por #{i.unit}") : bad("Sin costo", "Escríbelo en la lista (columna Costo)."))
    links = i.supplier_links.to_a
    out << (links.any? ? ok("Vinculada a #{pl(links.size, "producto o variante", "productos o variantes")}") : bad("No está vinculada a ningún producto ni variante", "Sin vínculo no se puede exportar. Agrégalo en «Dónde se usa»."))
    out << info("Proveedor: #{i.provider.name}")
    out
  end
end
