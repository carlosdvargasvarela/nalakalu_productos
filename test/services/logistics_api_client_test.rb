# test/services/logistics_api_client_test.rb
require "test_helper"

class LogisticsApiClientTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
    @client = LogisticsApiClient.new
  end

  test "clean_filters incluye archived (incluso cuando es false) y updated_since formateado" do
    cleaned = @client.send(:clean_filters,
      from: "2026-06-01",
      archived: false,
      updated_since: Time.zone.parse("2026-06-01T12:30:00Z"),
      page: 2,
      per_page: 100
    )

    assert_equal "2026-06-01", cleaned[:from]
    assert_equal false, cleaned[:archived]
    assert_equal "2026-06-01T12:30:00Z", cleaned[:updated_since]
    assert_equal 2, cleaned[:page]
    assert_equal 100, cleaned[:per_page]
  end

  test "clean_filters descarta nil y cadenas vacías pero conserva false" do
    cleaned = @client.send(:clean_filters, from: "", to: nil, archived: false, status: "ready_to_deliver")

    refute cleaned.key?(:from)
    refute cleaned.key?(:to)
    assert_equal false, cleaned[:archived]
    assert_equal "ready_to_deliver", cleaned[:status]
  end

  test "build_cache_key distingue por archived y updated_since" do
    base = @client.send(:build_cache_key, from: "2026-06-01", to: "2026-06-07")
    with_archived = @client.send(:build_cache_key, from: "2026-06-01", to: "2026-06-07", archived: true)
    with_since = @client.send(:build_cache_key, from: "2026-06-01", to: "2026-06-07", updated_since: "2026-06-01T00:00:00Z")

    refute_equal base, with_archived
    refute_equal base, with_since
    refute_equal with_archived, with_since
  end

  test "fetch_updated_deliveries pagina hasta agotar X-Total-Pages y no usa cache" do
    page1 = [{ "id" => 1, "updated_at" => "2026-06-01T00:00:00Z" }]
    page2 = [{ "id" => 2, "updated_at" => "2026-06-02T00:00:00Z" }]

    responses = [
      FakeResponse.new(success: true, body: page1, headers: { "X-Total-Pages" => "2" }),
      FakeResponse.new(success: true, body: page2, headers: { "X-Total-Pages" => "2" })
    ]

    connection = FakeConnection.new(responses)
    @client.instance_variable_set(:@connection, connection)

    result = @client.fetch_updated_deliveries(since: Time.zone.parse("2026-05-01T00:00:00Z"), per_page: 1)

    assert_equal [page1.first, page2.first], result
    assert_equal 2, connection.requests.size
    assert_equal 1, connection.requests[0][:params][:page]
    assert_equal 2, connection.requests[1][:params][:page]
    assert_equal "2026-05-01T00:00:00Z", connection.requests[0][:params][:updated_since]
  end

  test "fetch_updated_deliveries detiene la paginación si una página llega vacía" do
    responses = [
      FakeResponse.new(success: true, body: [{ "id" => 1, "updated_at" => "2026-06-01T00:00:00Z" }], headers: { "X-Total-Pages" => "5" }),
      FakeResponse.new(success: true, body: [], headers: { "X-Total-Pages" => "5" })
    ]

    connection = FakeConnection.new(responses)
    @client.instance_variable_set(:@connection, connection)

    result = @client.fetch_updated_deliveries(since: Time.zone.parse("2026-05-01T00:00:00Z"), per_page: 1)

    assert_equal 1, result.size
    assert_equal 2, connection.requests.size
  end

  FakeResponse = Struct.new(:success, :body, :headers, keyword_init: true) do
    def success?
      success
    end
  end

  class FakeConnection
    attr_reader :requests

    def initialize(responses)
      @responses = responses
      @requests = []
    end

    def get(path, params = {})
      @requests << { path: path, params: params }
      @responses[@requests.size - 1]
    end
  end
end
