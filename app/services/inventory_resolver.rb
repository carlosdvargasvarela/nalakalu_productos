class InventoryResolver
  def self.resolve_delivery(delivery, sync)
    new(delivery, sync).resolve
  end

  def initialize(delivery, sync)
    @delivery = delivery
    @sync     = sync
  end

  def resolve
    classified = InventoryClassifier.classify(@delivery)
    return [] if classified.empty?

    results = []

    classified.each do |c|
      item = c.item

      # Skip if already recorded in a confirmed sync (idempotency)
      next if confirmed_duplicate?(item["id"], c.type, c.sala)

      decoding   = ProductDecoder.decode(item["product_name"].to_s)
      product_id = decoding.base_product&.id
      status     = product_id.present? ? "resolved" : "unresolved"

      movement = InventoryMovement.find_or_initialize_by(
        delivery_item_id: item["id"],
        movement_type:    c.type,
        sala:             c.sala
      )

      movement.assign_attributes(
        inventory_sync:   @sync,
        product_id:       product_id,
        delivery_id:      @delivery["id"],
        delivery_date:    @delivery["delivery_date"],
        order_number:     @delivery["order_number"],
        client_name:      @delivery.dig("client", "name"),
        product_name_raw: item["product_name"],
        quantity:         item["quantity_delivered"].to_f,
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

  private

  def confirmed_duplicate?(item_id, movement_type, sala)
    return false if item_id.nil?

    InventoryMovement
      .confirmed_only
      .where(delivery_item_id: item_id, movement_type: movement_type, sala: sala)
      .exists?
  end
end
