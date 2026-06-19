# test/controllers/inventory_dashboard_controller_test.rb
require "test_helper"

class InventoryDashboardControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    sign_in users(:admin)
    @original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
  end

  teardown do
    ActiveJob::Base.queue_adapter = @original_adapter
  end

  test "sync redirige con alerta y no encola el job si ya hay un pendiente que se superpone" do
    overlapping = InventorySync.create!(from_date: "2026-06-10", to_date: "2026-06-15", status: "pending_review")

    assert_no_enqueued_jobs only: SyncInventoryJob do
      post sync_inventory_url, params: { from: "2026-06-12", to: "2026-06-20" }
    end

    assert_redirected_to inventory_sync_path(overlapping)
    assert_match "superpone", flash[:alert]
  end

  test "sync encola el job cuando no hay superposición" do
    assert_enqueued_with(job: SyncInventoryJob) do
      post sync_inventory_url, params: { from: "2026-06-10", to: "2026-06-15" }
    end

    assert_redirected_to inventory_path
  end
end
