class InventoryResolver
  def self.resolve_deliveries(deliveries, sync)
    new(sync).resolve(deliveries)
  end

  def initialize(sync)
    @sync = sync
    # Each unique product_name is decoded exactly once per sync run, regardless of
    # how many deliveries/items repeat it — reduces ProductDecoder O(n×products) calls.
    @decoded_by_name = Hash.new { |h, name| h[name] = ProductDecoder.decode(name) }
  end

  def resolve(deliveries)
    deliveries.flat_map { |delivery| resolve_delivery(delivery) }
  end

  private

  def resolve_delivery(delivery)
    classified = InventoryClassifier.classify(delivery)
    return [] if classified.empty?

    results = []

    classified.each do |c|
      item        = c.item
      showroom_id = c.showroom&.id

      next if confirmed_duplicate?(item["id"], c.type, showroom_id)

      decoding   = @decoded_by_name[item["product_name"].to_s]
      product_id = decoding.base_product&.id
      status     = "unresolved"

      movement = InventoryMovement.find_or_initialize_by(
        delivery_item_id: item["id"],
        movement_type:    c.type,
        showroom_id:      showroom_id
      )

      movement.assign_attributes(
        inventory_sync:   @sync,
        product_id:       product_id,
        delivery_id:      delivery["id"],
        delivery_date:    delivery["delivery_date"],
        order_number:     delivery["order_number"],
        client_name:      delivery.dig("client", "name"),
        delivery_status:  delivery["status"],
        product_name_raw: item["product_name"],
        quantity:         item["quantity_delivered"].to_f,
        source:           "synced",
        status:           movement.persisted? ? movement.status : status
      )

      if movement.save
        results << movement
      else
        Rails.logger.error "[InventoryResolver] #{movement.errors.full_messages.join(", ")} — #{item["product_name"]}"
      end
    end

    results
  end

  def confirmed_duplicate?(item_id, movement_type, showroom_id)
    return false if item_id.nil?

    InventoryMovement
      .confirmed_only
      .where(delivery_item_id: item_id, movement_type: movement_type, showroom_id: showroom_id)
      .exists?
  end
end
