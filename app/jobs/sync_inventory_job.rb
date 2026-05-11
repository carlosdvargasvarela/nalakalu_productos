class SyncInventoryJob < ApplicationJob
  queue_as :inventory

  def perform(from:, to:, user_id: nil)
    sync = InventorySync.create!(
      from_date: from,
      to_date:   to,
      status:    "pending_review",
      synced_at: Time.current
    )

    deliveries = LogisticsApiClient.fetch_deliveries(from: from, to: to)

    movements = deliveries.flat_map do |delivery|
      InventoryResolver.resolve_delivery(delivery, sync)
    end

    sync.update!(
      deliveries_processed: deliveries.size,
      movements_count:      movements.size,
      unresolved_count:     movements.count { |m| m.status == "unresolved" }
    )

    Rails.logger.info(
      "[SyncInventoryJob] sync=#{sync.id} from=#{from} to=#{to} " \
      "entregas=#{deliveries.size} movimientos=#{movements.size} " \
      "no_resueltos=#{sync.unresolved_count}"
    )
  rescue => e
    sync&.destroy
    raise e
  ensure
    ProductDecoder.clear_cache!
  end
end
