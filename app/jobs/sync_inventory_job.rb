class SyncInventoryJob < ApplicationJob
  queue_as :inventory

  def perform(from: nil, to: nil, user_id: nil)
    config = InventorySyncConfig.current
    from ||= (Date.current - config.schedule_days_back.days).to_s
    to   ||= Date.current.to_s

    if (overlapping = InventorySync.pending_logistics_sync_overlapping(from, to))
      Rails.logger.info(
        "[SyncInventoryJob] omitido: sync ##{overlapping.id} (#{overlapping.from_date}..#{overlapping.to_date}) " \
        "ya está pendiente y se superpone con #{from}..#{to}"
      )
      return
    end

    sync = InventorySync.create!(
      from_date: from,
      to_date:   to,
      status:    "pending_review",
      synced_at: Time.current
    )

    deliveries = LogisticsApiClient.new.fetch_updated_deliveries(
      since: nil, from: from, to: to
    )

    movements = InventoryResolver.resolve_deliveries(deliveries, sync)

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
