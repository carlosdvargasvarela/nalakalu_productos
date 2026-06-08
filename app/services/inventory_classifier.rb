class InventoryClassifier
  Result = Struct.new(:type, :showroom, :item, keyword_init: true)

  def self.classify(delivery)
    new(delivery).classify
  end

  def initialize(delivery)
    @delivery     = delivery
    @order_number = delivery["order_number"].to_s
  end

  def classify
    items = Array(@delivery["items"]).select { |item| item["quantity_delivered"].to_f > 0 }
    return [] if items.empty?

    results = []
    add_inter_sala_results(items, results)
    add_main_restock_results(items, results)
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

  # Rule 2: main-sala restock — independent of Rule 1.
  # If order_number starts with any of the is_main showroom's configured prefixes,
  # generate an entry toward that sala.
  def add_main_restock_results(items, results)
    main = main_showroom
    return unless main && restock_order?(main)

    items.each { |item| results << Result.new(type: "entry", showroom: main, item: item) }
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
