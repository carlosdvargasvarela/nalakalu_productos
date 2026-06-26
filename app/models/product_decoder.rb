class ProductDecoder
  CACHE_KEY_PRODUCTS = "decoder:products:v1"
  CACHE_KEY_VARIANTS = "decoder:variants:v1"
  CACHE_TTL = 30.minutes

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

  STOP_WORDS = %w[de del la el los las un una y con sin para por al a].to_set

  def self.significant_tokens(tokens)
    tokens.reject { |t| t.length <= 1 || STOP_WORDS.include?(t) }
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
    strict = normalize_strict(full_code)
    input_tokens = significant_tokens(normalize_loose(full_code).split)
    return nil if input_tokens.empty?

    best_product = nil
    best_score = -1.0

    all_products_cache.each do |p|
      p_strict = normalize_strict(p.name)

      if strict.include?(p_strict)
        score = 100 + p.name.length
      else
        p_tokens = significant_tokens(normalize_loose(p.name).split)
        next if p_tokens.empty?
        inter = input_tokens & p_tokens
        recall = inter.size.to_f / p_tokens.size
        next if recall < 0.6
        precision = inter.size.to_f / input_tokens.size
        score = recall + precision * 0.5 + (p.name.length / 100.0)
      end

      if score > best_score
        best_product = p
        best_score = score
      end
    end

    best_product
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
