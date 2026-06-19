class InventoryClassifier
  Result = Struct.new(:type, :showroom, :item, keyword_init: true)

  def self.classify(delivery, showrooms_by_code: nil, exit_order_prefixes: nil)
    new(delivery, showrooms_by_code: showrooms_by_code, exit_order_prefixes: exit_order_prefixes).classify
  end

  def initialize(delivery, showrooms_by_code: nil, exit_order_prefixes: nil)
    @delivery             = delivery
    @order_number         = delivery["order_number"].to_s
    @showrooms_by_code    = showrooms_by_code
    @exit_order_prefixes  = exit_order_prefixes
  end

  def classify
    items = Array(@delivery["items"]).select { |item| item["quantity_delivered"].to_f > 0 }
    return [] if items.empty?

    results = []
    add_inter_sala_results(items, results)
    add_main_restock_results(items, results)
    add_keyword_exit_results(items, results)
    results
  end

  private

  # Rule 1: inter-sala movement based on structured source_showroom/destination_showroom.
  # Both, one, or neither may be present; each generates its own movements independently.
  def add_inter_sala_results(items, results)
    source      = matching_showroom(@delivery["source_showroom"])
    destination = matching_showroom(@delivery["destination_showroom"])
    return unless source || destination

    items.each do |item|
      results << Result.new(type: "exit",  showroom: source,      item: item) if source
      results << Result.new(type: "entry", showroom: destination, item: item) if destination
    end
  end

  # Rule 2: prefix-based restock — independent of Rule 1.
  # For every active showroom whose order_number_prefixes_array includes a prefix
  # that matches the current order_number, generate an entry toward that showroom.
  # This covers both main-showroom restocks and non-main inter-sala transfers
  # whose order numbers start with a configured prefix (e.g. "2-", "3-").
  def add_main_restock_results(items, results)
    showrooms_by_code.each_value do |showroom|
      next unless restock_order?(showroom)
      items.each { |item| results << Result.new(type: "entry", showroom: showroom, item: item) }
    end
  end

  # Rule 3: keyword-based exit — independent of Rules 1 and 2.
  # Only evaluated for order_numbers matching a globally configured "exit order"
  # prefix (e.g. "PED-4"), since plain client sale orders carry no structured
  # source_showroom. Within those, each item's product_name is checked against
  # every active showroom's product_keywords; exactly one match resolves the
  # showroom, zero matches generate nothing, and 2+ matches are left ambiguous
  # (showroom: nil) for manual resolution in the review screen.
  def add_keyword_exit_results(items, results)
    return unless exit_order?

    items.each do |item|
      matches = showrooms_matching_product_keyword(item["product_name"])
      next if matches.empty?

      results << Result.new(type: "exit", showroom: matches.size == 1 ? matches.first : nil, item: item)
    end
  end

  def exit_order?
    exit_order_prefixes.any? { |prefix| @order_number.start_with?(prefix) }
  end

  def exit_order_prefixes
    @exit_order_prefixes ||= InventorySyncConfig.current.exit_order_prefixes_array
  end

  def showrooms_matching_product_keyword(product_name)
    name = product_name.to_s.upcase
    showrooms_by_code.values.select do |showroom|
      showroom.product_keywords_array.any? { |keyword| name.include?(keyword.upcase) }
    end
  end

  def matching_showroom(showroom_data)
    return nil unless showroom_data.is_a?(Hash)

    showrooms_by_code[showroom_data["code"].to_s.upcase]
  end

  def main_showroom
    showrooms_by_code.values.find(&:is_main?)
  end

  def restock_order?(showroom)
    prefixes = showroom.order_number_prefixes_array
    prefixes.present? && prefixes.any? { |prefix| @order_number.start_with?(prefix) }
  end

  def showrooms_by_code
    @showrooms_by_code ||= Showroom.active.index_by(&:code)
  end
end
