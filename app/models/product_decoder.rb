# app/models/product_decoder.rb
class ProductDecoder
  def self.decode(full_code)
    return {has_variants: false, base_product: nil, variants: [], unrecognized_codes: []} if full_code.blank?

    working_string = full_code.dup
    found_variants = []
    base_product = nil

    # 1. CAPA 1: Identificar el Producto Base (Prioridad nombres largos)
    # Buscamos el producto cuyo nombre sea el match más largo dentro del string
    all_products = Product.where(active: true).order(Arel.sql("LENGTH(name) DESC"))
    base_product = all_products.find { |p| working_string.downcase.include?(p.name.downcase) }

    if base_product
      # "Restamos" el nombre del producto del string para que no estorbe
      working_string.gsub!(/#{Regexp.escape(base_product.name)}/i, "")
    end

    # 2. CAPA 2: Identificar Variantes Contextuales (Si hay producto base)
    if base_product
      # Solo buscamos variantes de los tipos que este producto permite
      allowed_type_ids = base_product.product_variant_rules.pluck(:variant_type_id)

      # Buscamos variantes de esos tipos, priorizando nombres largos (ej: "Azul Petróleo" antes que "Azul")
      contextual_variants = Variant.where(variant_type_id: allowed_type_ids)
        .order(Arel.sql("LENGTH(display_name) DESC, LENGTH(name) DESC"))

      contextual_variants.each do |v|
        # Buscamos por display_name, name o code
        [v.display_name, v.name, v.code].compact.uniq.each do |term|
          next if term.length < 2 # Evitar ruidos de 1 letra

          if working_string.downcase.include?(term.downcase)
            found_variants << v
            working_string.gsub!(/#{Regexp.escape(term)}/i, "") # Lo "restamos"
            break # Pasamos a la siguiente variante
          end
        end
      end
    end

    # 3. CAPA 3: Búsqueda Global (Para lo que quedó o si no hubo producto base)
    # Esto ayuda a detectar variantes que quizás no están en las reglas pero sí en el string
    remaining_segments = working_string.split(/[-\s\/]+/).map(&:strip).reject { |s| s.blank? || %w[stock de sala].include?(s.downcase) }
    unrecognized_codes = []

    remaining_segments.each do |segment|
      # Intentamos una última búsqueda global por si acaso
      global_variant = Variant.find_by("display_name = ? OR name = ? OR code = ?", segment, segment, segment)

      if global_variant
        found_variants << global_variant unless found_variants.include?(global_variant)
      else
        # Si después de todo no es nada, es un código no reconocido
        # Pero ignoramos si es parte del nombre del producto base que ya encontramos
        unless base_product && base_product.name.downcase.include?(segment.downcase)
          unrecognized_codes << segment
        end
      end
    end

    {
      has_variants: found_variants.any?,
      base_product: base_product,
      variants: found_variants.uniq,
      unrecognized_codes: unrecognized_codes.uniq
    }
  end
end
