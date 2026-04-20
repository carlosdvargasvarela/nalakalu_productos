# app/services/logistics_api_client.rb
class LogisticsApiClient
  BASE_URL = ENV["LOGISTICS_API_URL"]
  CACHE_TTL = 5.minutes
  TIMEOUT_SEC = 10

  def self.fetch_deliveries(filters = {})
    new.fetch_deliveries(filters)
  end

  def initialize
    @connection = Faraday.new(url: BASE_URL) do |f|
      f.request :json
      f.response :json
      f.request :retry, max: 2, interval: 0.5, exceptions: [
        Faraday::TimeoutError, Faraday::ConnectionFailed
      ]
      f.options.timeout = TIMEOUT_SEC
      f.options.open_timeout = 5
      f.ssl[:verify] = false
      f.adapter Faraday.default_adapter
    end
  end

  def fetch_delivery(id)
    response = @connection.get("deliveries/#{id}")
    response.success? ? response.body : nil
  rescue Faraday::Error => e
    Rails.logger.error "[LogisticsApiClient] fetch_delivery(#{id}): #{e.message}"
    nil
  end

  def fetch_deliveries(filters = {})
    cache_key = build_cache_key(filters)

    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      response = @connection.get("deliveries", clean_filters(filters))

      if response.success?
        response.body
      else
        Rails.logger.error "[LogisticsApiClient] #{response.status}: #{response.body}"
        nil  # nil → no cachear (ver abajo)
      end
    rescue Faraday::Error => e
      Rails.logger.error "[LogisticsApiClient] fetch_deliveries: #{e.message}"
      nil
    end || []
  end

  # Invalida el cache para un rango — llamar desde sync_delivery
  def self.invalidate_cache!(filters = {})
    Rails.cache.delete(new.send(:build_cache_key, filters))
  end

  private

  def build_cache_key(filters)
    parts = [
      "logistics_deliveries",
      filters[:from],
      filters[:to],
      filters[:order_number],
      filters[:seller_code],
      filters[:status]
    ].map(&:to_s)
    parts.join("/")
  end

  def clean_filters(filters)
    filters.slice(:from, :to, :status, :order_number, :seller_code)
      .reject { |_, v| v.blank? }
  end
end
