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
    results      = []
    destination  = entry_destination
    source_salas = exit_salas

    items = Array(@delivery["items"])

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

  # Sala de entrada: prioriza el dato estructurado de la API de Rutas
  # (destination_showroom). Si no viene o su código no corresponde a una
  # sala que rastreamos en inventario, conserva la heurística por regex.
  def entry_destination
    showroom_sala(@delivery["destination_showroom"]) || regex_entry_destination
  end

  def regex_entry_destination
    # PED- orders are customer deliveries — no inventory entry
    return nil if customer_order?
    # Mandado orders don't affect sala inventory
    return nil if mandado_order?

    detect_destination
  end

  # Salas de salida: prioriza source_showroom (single sala estructurada);
  # si no viene o no es una sala rastreada, conserva la detección por regex
  # sobre las líneas indicadoras de los ítems ("tomar de SE", etc.).
  def exit_salas
    sala = showroom_sala(@delivery["source_showroom"])
    return { sala => true } if sala

    salas = {}
    Array(@delivery["items"]).each do |item|
      detected = exit_sala_from(item["product_name"].to_s)
      salas[detected] = true if detected
    end
    salas
  end

  # Mapea un showroom estructurado ({"id" => .., "name" => .., "code" => ..})
  # a la sala interna (SP/SE/SG). El `code` de la API de Rutas coincide con
  # los códigos internos; si no es uno de los que rastreamos, devuelve nil
  # para que el llamador caiga al respaldo por regex.
  def showroom_sala(showroom)
    return nil unless showroom.is_a?(Hash)

    code = showroom["code"].to_s
    InventoryMovement::SALAS.include?(code) ? code : nil
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
