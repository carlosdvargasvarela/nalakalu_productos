# app/jobs/sync_deliveries_job.rb
class SyncDeliveriesJob < ApplicationJob
  queue_as :procurement

  def perform(from:, to:, user_id: nil)
    cursor = LogisticsSyncCursor.current
    deliveries = LogisticsApiClient.new.fetch_updated_deliveries(
      since: cursor.last_synced_at, from: from, to: to
    )

    results = deliveries.flat_map do |delivery|
      ProcurementResolver.resolve_delivery(delivery)
    end

    new_count = results.count(&:previously_new_record?)
    existing_count = results.size - new_count

    cursor.advance_to!(deliveries.filter_map { |d| d["updated_at"] }.max)

    Rails.logger.info(
      "[SyncDeliveriesJob] from=#{from} to=#{to} " \
      "nuevos=#{new_count} existentes=#{existing_count} " \
      "entregas_modificadas=#{deliveries.size}"
    )
  ensure
    ProductDecoder.clear_cache!
    ProcurementResolver.clear_cache!
  end
end
