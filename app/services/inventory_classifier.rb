class InventoryClassifier
  NALAKALU_RE    = /nalakal[uú]|na\s+lakal[uú]/i
  ESCAZU_RE      = /esc[aá]z[uú]/i
  GUANACASTE_RE  = /guanacaste/i
  CUSTOMER_ORDER_RE = /\APED-/i
  MANDADO_RE     = /\Amandado/i

  EXIT_SALA_RE = {
    "SP" => /\bSP\b|sala\s*palmares|tomar\s+de\s+SP/i,
    "SE" => /\bSE\b|sala\s*esc[aá]z[uú]|tomar\s+de\s+SE/i,
    "SG" => /\bSG\b|sala\s*guanacaste|tomar\s+de\s+SG/i
  }.freeze

  Result = Struct.new(:type, :sala, :item, keyword_init: true)

  def self.classify(delivery)
    new(delivery).classify
  end

  def initialize(delivery)
    @delivery     = delivery
    @order_number = delivery["order_number"].to_s
    @client_name  = delivery.dig("client", "name").to_s
  end

  def classify
    results     = []
    source_salas = {}

    items = Array(@delivery["items"])

    # First pass: identify exit-indicator lines and source salas
    items.each do |item|
      sala = exit_sala_from(item["product_name"].to_s)
      source_salas[sala] = true if sala
    end

    destination = entry_destination

    # Second pass: generate movements for real product lines
    items.each do |item|
      next if exit_sala_from(item["product_name"].to_s)  # skip indicator lines
      next if item["quantity_delivered"].to_f <= 0

      results << Result.new(type: "entry", sala: destination, item: item) if destination

      source_salas.each_key do |sala|
        results << Result.new(type: "exit", sala: sala, item: item)
      end
    end

    results
  end

  private

  def entry_destination
    # PED- orders are customer deliveries — no inventory entry
    return nil if customer_order?
    # Mandado orders don't affect sala inventory
    return nil if mandado_order?

    detect_destination
  end

  def detect_destination
    return "SE" if @client_name.match?(ESCAZU_RE)
    return "SG" if @client_name.match?(GUANACASTE_RE)
    "SP"
  end

  def customer_order?
    @order_number.match?(CUSTOMER_ORDER_RE)
  end

  def mandado_order?
    @order_number.match?(MANDADO_RE)
  end

  def exit_sala_from(product_name)
    EXIT_SALA_RE.each { |sala, re| return sala if product_name.match?(re) }
    nil
  end
end
