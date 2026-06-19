require "test_helper"
require "minitest/mock"

class SyncInventoryJobTest < ActiveJob::TestCase
  test "no crea un sync nuevo si ya hay uno pendiente que se superpone en fechas" do
    InventorySync.create!(from_date: "2026-06-10", to_date: "2026-06-15", status: "pending_review")

    assert_no_difference -> { InventorySync.count } do
      SyncInventoryJob.perform_now(from: "2026-06-12", to: "2026-06-20")
    end
  end

  test "crea el sync cuando no hay superposición pendiente" do
    fake_client = Object.new
    def fake_client.fetch_updated_deliveries(*) = []

    LogisticsApiClient.stub :new, fake_client do
      assert_difference -> { InventorySync.count }, 1 do
        SyncInventoryJob.perform_now(from: "2026-06-10", to: "2026-06-15")
      end
    end
  end
end
