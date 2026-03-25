# app/models/product_decoder.rb
class ProductDecoder
  Result = Struct.new(
    :has_variants,
    :base_product,
    :variants,
    :unrecognized_codes,
    keyword_init: true
  )

  def self.decode(full_code, base_product: nil)
    return empty_result unless full_code.present?

    base_product ||= detect_base_product(full_code)
    return empty_result unless base_product

    if base_product.product_variant_rules.empty?
      return Result.new(
        has_variants: false,
        base_product: base_product,
        variants: [],
        unrecognized_codes: []
      )
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

  # --- Normalización ---

  def self.normalize_strict(text)
    text.to_s.downcase.tr("áéíóúüñ", "aeiouun").squeeze(" ").strip
  end

  def self.normalize_loose(text)
    t = text.to_s.downcase.tr("áéíóúüñ", "aeiouun")
    t = t.gsub(/([a-z]+)[-\s]*([0-9]+)/, '\1\2')
    t = t.gsub(/[^a-z0-9\s]+/, " ")
    t.squeeze(" ").strip
  end

  def self.strip_product_from_string(input_strict, product_strict)
    return input_strict if product_strict.blank?
    if (idx = input_strict.index(product_strict))
      return input_strict[(idx + product_strict.length)..].to_s.strip
    end
    input_strict
  end

  # --- Detección de Producto Base ---

  def self.detect_base_product(full_code)
    strict = normalize_strict(full_code)
    loose = normalize_loose(full_code)
    input_tokens = loose.split
    return nil if input_tokens.empty?

    best_product = nil
    best_score = -1.0

    Product.where(active: true).find_each do |p|
      p_strict = normalize_strict(p.name)
      p_loose = normalize_loose(p.name)

      if strict.include?(p_strict)
        score = 100 + p.name.length
      else
        p_tokens = p_loose.split
        next if p_tokens.empty?
        inter = input_tokens & p_tokens
        recall = inter.size.to_f / p_tokens.size
        next if recall < 0.6
        score = recall + (p.name.length / 1000.0)
      end

      if score > best_score
        best_product = p
        best_score = score
      end
    end

    best_product
  end

  # --- Detección de Variantes ---

  def self.detect_variants_catalog_based(base_product, _tail_strict, tail_loose)
    tail_tokens = tail_loose.split
    return [] if tail_tokens.empty?
    tail_set = tail_tokens.to_set

    allowed_type_ids = base_product.product_variant_rules.pluck(:variant_type_id)
    return [] if allowed_type_ids.empty?

    candidates = []

    Variant.where(variant_type_id: allowed_type_ids, active: true).find_each do |v|
      v_name_loose = normalize_loose(v.seller_name)
      v_name_tokens = v_name_loose.split.uniq
      v_code_loose = v.code.present? ? normalize_loose(v.code) : nil

      code_match = v_code_loose.present? && tail_set.include?(v_code_loose)

      name_match = false
      if v_name_tokens.any?
        inter = v_name_tokens & tail_tokens
        coverage = inter.size.to_f / v_name_tokens.size
        name_match = (v_name_tokens.size == 1) ? tail_set.include?(v_name_tokens.first) : (coverage >= 0.6)
      end

      next unless code_match || name_match

      score = (code_match ? 2.0 : 0.0) + (name_match ? 1.0 : 0.0) + (v_name_tokens.size * 0.1)
      candidates << {variant: v, score: score, type_id: v.variant_type_id}
    end

    best_by_type = {}
    candidates.sort_by { |c| -c[:score] }.each do |c|
      next if best_by_type.key?(c[:type_id])
      best_by_type[c[:type_id]] = c[:variant]
    end

    best_by_type.values
  end

  def self.build_unrecognized_segments(tail_loose, variants)
    tokens = tail_loose.split
    explained = Array.new(tokens.size, false)

    variants.each do |v|
      v_text = "#{v.name} #{v.seller_name} #{v.code}"
      v_tokens = normalize_loose(v_text).split
      tokens.each_with_index { |t, i| explained[i] = true if v_tokens.include?(t) }
    end

    tokens.each_with_index.reject { |_, i| explained[i] }.map(&:first).uniq
  end

  def self.empty_result
    Result.new(has_variants: false, base_product: nil, variants: [], unrecognized_codes: [])
  end
end
