require "fuzzy_match"

class ProductDecoder
  CACHE_KEY_PRODUCTS = "decoder:products:v1"
  CACHE_KEY_VARIANTS = "decoder:variants:v1"
  CACHE_TTL = 30.minutes

  # Umbral mínimo de similitud (Dice's Coefficient, vía fuzzy_match) para aceptar
  # una detección de producto. Calibrado a mano contra el catálogo real: texto
  # sin relación real anota ~0.3-0.4, coincidencias legítimas (incluso abreviadas)
  # rondan 0.6+. Ver test/models/product_decoder_test.rb.
  MIN_MATCH_SCORE = 0.6

  Result = Struct.new(
    :has_variants, :base_product, :variants, :unrecognized_codes,
    keyword_init: true
  )

  def self.decode(full_code, base_product: nil)
    return empty_result unless full_code.present?

    base_product ||= detect_base_product(full_code)
    return empty_result unless base_product

    if base_product.product_variant_rules.empty?
      return Result.new(has_variants: false, base_product: base_product,
        variants: [], unrecognized_codes: [])
    end

    input_strict = normalize_strict(full_code)
    product_strict = normalize_strict(base_product.name)
    tail_strict = strip_product_from_string(input_strict, product_strict)
    tail_loose = normalize_loose(tail_strict)

    variants = detect_variants_catalog_based(base_product, tail_strict, tail_loose)
    unrec = build_unrecognized_segments(tail_loose, variants)

    Result.new(
      has_variants: variants.any?,
      base_product: base_product,
      variants: variants.uniq,
      unrecognized_codes: unrec
    )
  end

  # ── NORMALIZACIÓN ────────────────────────────────────────────────────────

  def self.normalize_strict(text)
    text.to_s.downcase.tr("áéíóúüñ", "aeiouun").squeeze(" ").strip
  end

  # Split at letter↔number boundaries so "3P"→"3 p", "oslo3"→"oslo 3",
  # "160CM"→"160 cm". Finer tokens → better cross-matching with abbreviated codes.
  def self.normalize_loose(text)
    t = text.to_s.downcase.tr("áéíóúüñ", "aeiouun")
    t = t.gsub(/[^a-z0-9]+/, " ")
    t = t.gsub(/([a-z])([0-9])/, '\1 \2')
    t = t.gsub(/([0-9])([a-z])/, '\1 \2')
    t.squeeze(" ").strip
  end

  def self.strip_product_from_string(input_strict, product_strict)
    return input_strict if product_strict.blank?
    if (idx = input_strict.index(product_strict))
      return input_strict[(idx + product_strict.length)..].to_s.strip
    end
    input_strict
  end

  # ── PRODUCT DETECTION ────────────────────────────────────────────────────

  def self.detect_base_product(full_code)
    needle = normalize_strict(full_code)
    return nil if needle.blank?

    # Camino rápido: el nombre del producto aparece tal cual dentro del texto
    # (el caso más común). fuzzy_match usa Dice's Coefficient sobre el string
    # completo, así que texto de más alrededor del nombre (pedido, notas, etc.)
    # diluye el score — por eso el substring match va primero, no como respaldo.
    exact_matches = all_products_cache.select { |p| needle.include?(normalize_strict(p.name)) }
    return exact_matches.max_by { |p| p.name.length } if exact_matches.any?

    match, score, = product_matcher.find_with_score(needle)
    return nil unless match && score && score >= MIN_MATCH_SCORE

    match
  end

  # fuzzy_match (Dice's Coefficient + Levenshtein) reemplaza el scoring manual
  # de recall/precision por tokens. Reconstruir el índice es barato (~0.4ms
  # para 550 productos) así que no vale la pena cachear el objeto FuzzyMatch en
  # sí — basta con que all_products_cache ya esté cacheado.
  def self.product_matcher
    FuzzyMatch.new(all_products_cache, read: ->(p) { normalize_strict(p.name) })
  end

  # ── VARIANT DETECTION ────────────────────────────────────────────────────

  def self.detect_variants_catalog_based(base_product, _tail_strict, tail_loose)
    tail_tokens = tail_loose.split
    return [] if tail_tokens.empty?

    tail_set = tail_tokens.to_set
    allowed_type_ids = base_product.product_variant_rules.map(&:variant_type_id)
    return [] if allowed_type_ids.empty?

    candidates = []

    all_variants_cache.each do |v|
      next unless allowed_type_ids.include?(v.variant_type_id)

      v_name_loose = normalize_loose(v.seller_name)
      v_name_tokens = v_name_loose.split.uniq
      # Code may expand to multiple tokens after splitting (e.g. "3P"→["3","p"]);
      # require ALL code tokens to be present in the tail.
      v_code_tokens = v.code.present? ? normalize_loose(v.code).split : []

      code_match = v_code_tokens.any? && v_code_tokens.all? { |ct| tail_set.include?(ct) }
      name_match = false

      if v_name_tokens.any?
        inter = v_name_tokens & tail_tokens
        coverage = inter.size.to_f / v_name_tokens.size
        # 1-token variant: exact; multi-token: ≥50% coverage (1 of 2 tokens is enough).
        name_match = v_name_tokens.size == 1 ? coverage == 1.0 : coverage >= 0.5
      end

      next unless code_match || name_match

      score = (code_match ? 2.0 : 0.0) + (name_match ? 1.0 : 0.0) + (v_name_tokens.size * 0.1)
      candidates << {variant: v, score: score, type_id: v.variant_type_id}
    end

    best_by_type = {}
    candidates.sort_by { |c| -c[:score] }.each do |c|
      best_by_type[c[:type_id]] ||= c[:variant]
    end

    best_by_type.values
  end

  def self.build_unrecognized_segments(tail_loose, variants)
    tokens = tail_loose.split
    explained = Array.new(tokens.size, false)

    variants.each do |v|
      v_tokens = normalize_loose("#{v.name} #{v.seller_name} #{v.code}").split
      tokens.each_with_index { |t, i| explained[i] = true if v_tokens.include?(t) }
    end

    tokens.each_with_index.reject { |_, i| explained[i] }.map(&:first).uniq
  end

  # ── CACHE (SOLO Rails.cache) ─────────────────────────────────────────────

  def self.all_products_cache
    Rails.cache.fetch(CACHE_KEY_PRODUCTS, expires_in: CACHE_TTL) do
      Product
        .where(active: true)
        .includes(:product_variant_rules)
        .select(:id, :name, :base_code)
        .to_a
    end
  end

  def self.all_variants_cache
    Rails.cache.fetch(CACHE_KEY_VARIANTS, expires_in: CACHE_TTL) do
      Variant
        .where(active: true)
        .includes(:variant_type)
        .select(:id, :name, :display_name, :code, :variant_type_id)
        .to_a
    end
  end

  def self.clear_cache!
    Rails.cache.delete(CACHE_KEY_PRODUCTS)
    Rails.cache.delete(CACHE_KEY_VARIANTS)
  end

  def self.empty_result
    Result.new(has_variants: false, base_product: nil, variants: [], unrecognized_codes: [])
  end
end
