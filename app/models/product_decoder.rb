# app/models/product_decoder.rb
class ProductDecoder
  def self.decode(full_code)
    return {has_variants: false, base_product: nil, variants: [], unrecognized_codes: []} if full_code.blank?

    # 1. Limpieza y segmentación
    # Separamos por guiones, espacios o slashes para ser extra-flexibles
    segments = full_code.split(/[-\s\/]+/).map(&:strip).reject(&:blank?)

    found_variants = []
    unrecognized_codes = []
    base_product = nil

    # 2. Intentamos identificar el producto base en CUALQUIER segmento
    # (Por si el código oficial está al final o en medio)
    segments.each do |segment|
      product = Product.find_by(base_code: segment)
      if product
        base_product = product
        break # Encontramos el base, dejamos de buscar bases
      end
    end

    # 3. Buscamos variantes para TODOS los segmentos
    # Incluso si un segmento es el nombre coloquial "Banco", no pasará nada porque no habrá
    # una variante con código "Banco".
    segments.each do |segment|
      # Saltamos el segmento si ya sabemos que es el producto base
      next if base_product && segment == base_product.base_code

      variant = Variant.find_by(code: segment)
      if variant
        found_variants << variant
      else
        # Si no es producto base y no es variante, es un código no reconocido
        # Pero solo lo agregamos si no es el nombre del producto base (ej: "Dalila")
        unrecognized_codes << segment unless base_product && base_product.name.include?(segment)
      end
    end

    {
      has_variants: found_variants.any?,
      base_product: base_product,
      variants: found_variants.uniq,
      # Filtramos los segmentos que son parte del nombre del producto base para no ensuciar
      unrecognized_codes: unrecognized_codes.uniq
    }
  end
end
