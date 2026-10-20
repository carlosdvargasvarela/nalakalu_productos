# Sugiere vínculos pieza <-> variante/producto por parecido de nombre.
# Compara palabras (sin tildes, singular, tolerando typos) ponderadas por rareza; una palabra suelta no basta
# (colores como «blanco» o «lino» están en cientos de nombres), y números distintos restan (TIRADERA 10 ≠ TIR-09).
class NameMatcher
  THRESHOLD = 0.75
  STOP = %w[de del la las el los y e o con para por en a al un una x sin se su].to_set.freeze
  Suggestion = Struct.new(:record, :score, :common) do
    def percent = (score * 100).round
  end

  def self.tokens(text)
    I18n.transliterate(text.to_s).downcase.gsub(/[^a-z0-9]+/, " ").split
      .reject { STOP.include?(_1) || (_1.size == 1 && _1 !~ /\d/) }
      .map { |t| (t.size > 4 && t.end_with?("es")) ? t[0..-3] : ((t.size > 3 && t.end_with?("s")) ? t[0..-2] : t) }.uniq
  end

  def initialize
    @c = corpus
  end

  # Piezas que se parecen a una variante (menos las ya vinculadas a ella)
  def pieces_for_variant(variant, limit: 5)
    linked = variant.supplier_links.pluck(:supplier_item_id).to_set
    rank(NameMatcher.tokens(variant.seller_name), @c[:pieces], limit) { !linked.include?(_1) }.map { Suggestion.new(SupplierItem.find(_1.record), _1.score, _1.common) }
  end

  # Piezas que se parecen a un producto
  def pieces_for_product(product, limit: 5)
    linked = product.supplier_links.pluck(:supplier_item_id).to_set
    rank(NameMatcher.tokens(product.name), @c[:pieces], limit) { !linked.include?(_1) }.map { Suggestion.new(SupplierItem.find(_1.record), _1.score, _1.common) }
  end

  # Variantes y productos que se parecen a una pieza (menos los ya vinculados)
  def targets_for_piece(item, limit: 6)
    toks = NameMatcher.tokens(item.name)
    linked_v = item.supplier_links.pluck(:variant_id).compact.to_set
    linked_p = item.supplier_links.pluck(:product_id).compact.to_set
    vs = rank(toks, @c[:variants], limit) { !linked_v.include?(_1) }.map { Suggestion.new(Variant.includes(:variant_type).find(_1.record), _1.score, _1.common) }
    ps = rank(toks, @c[:products], limit) { !linked_p.include?(_1) }.map { Suggestion.new(Product.find(_1.record), _1.score, _1.common) }
    (vs + ps).sort_by { -_1.score }.first(limit)
  end

  private

  # [[id, tokens]] por tipo + frecuencia de cada palabra, cacheado mientras no cambien los datos
  def corpus
    key = ["name_matcher/v1", SupplierItem.count, Variant.count, Product.count, [SupplierItem, Variant, Product].map { _1.maximum(:updated_at)&.to_i }].flatten.join("/")
    Rails.cache.fetch(key, expires_in: 30.minutes) do
      pieces = SupplierItem.pluck(:id, :name).map { |i, n| [i, NameMatcher.tokens(n)] }
      variants = Variant.all.map { |v| [v.id, NameMatcher.tokens(v.seller_name)] }
      products = Product.pluck(:id, :name).map { |i, n| [i, NameMatcher.tokens(n)] }
      df = Hash.new(0)
      (pieces + variants + products).each { |_, t| t.each { df[_1] += 1 } }
      {pieces: pieces, variants: variants, products: products, df: df, n: (pieces.size + variants.size + products.size).to_f}
    end
  end

  def idf(word) = Math.log((@c[:n] + 1) / (@c[:df][word] + 1)) + 1

  def rank(tokens, candidates, limit)
    return [] if tokens.empty?

    candidates.filter_map do |id, ctoks|
      next unless yield(id)

      score, common = score(tokens, ctoks)
      Suggestion.new(id, score, common) if score >= THRESHOLD
    end.sort_by { -_1.score }.first(limit)
  end

  def score(a, b)
    return [0, []] if a.empty? || b.empty?

    common = []
    weight = 0.0
    a.each do |x|
      best = b.map { |y| similarity(x, y) }.max
      next unless best > 0

      common << x
      weight += idf(x) * best
    end
    return [0, []] if common.empty?

    # «números» = solo dígitos (9046, 10, 09): son códigos. Medidas como 50mm o 25mts no cuentan.
    nums_a, nums_b = a.select { _1.match?(/\A\d+\z/) }, b.select { _1.match?(/\A\d+\z/) }
    # un número que el otro nombre no trae no cuenta como diferencia (solo resta certeza); números distintos sí lo descartan
    wa = a.sum { |t| (nums_a.include?(t) && nums_b.empty?) ? 0 : idf(t) }
    wb = b.sum { |t| (nums_b.include?(t) && nums_a.empty?) ? 0 : idf(t) }
    smaller = [wa, wb].min
    return [0, []] if smaller <= 0

    penalty = if nums_a.any? && nums_b.any? then ((nums_a & nums_b).empty? ? 0.4 : 1.0)
    elsif nums_a.any? || nums_b.any? then 0.85 # el número no se pudo verificar
    else 1.0
    end
    strong = common.size >= 2 # una palabra suelta no basta
    [(weight / smaller) * penalty * (strong ? 1 : 0.4), common]
  end

  # 1 = igual; 0.8 = casi igual (typo) en palabras largas; 0 = distinta
  def similarity(x, y)
    return 1.0 if x == y
    return 0 unless x.size >= 5 && y.size >= 5 && !x.match?(/\d/) && !y.match?(/\d/) # typos solo en palabras largas sin dígitos

    dice(x, y) >= 0.75 ? 0.8 : 0
  end

  def dice(x, y)
    bx, by = x.chars.each_cons(2).map(&:join), y.chars.each_cons(2).map(&:join)
    return 0 if bx.empty? || by.empty?

    2.0 * (bx & by).size / (bx.size + by.size)
  end
end
