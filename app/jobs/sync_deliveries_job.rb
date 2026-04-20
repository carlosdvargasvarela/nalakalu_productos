# app/jobs/sync_deliveries_job.rb
class SyncDeliveriesJob < ApplicationJob
  queue_as :procurement

  def perform(from:, to:, user_id: nil)
    deliveries = LogisticsApiClient.fetch_deliveries(from: from, to: to)

    results = deliveries.flat_map do |delivery|
      ProcurementResolver.resolve_delivery(delivery)
    end

    new_count = results.count(&:previously_new_record?)
    existing_count = results.size - new_count

    Rails.logger.info(
      "[SyncDeliveriesJob] from=#{from} to=#{to} " \
      "nuevos=#{new_count} existentes=#{existing_count}"
    )
  ensure
    ProductDecoder.clear_cache!
    ProcurementResolver.clear_cache!
  end
end
