# app/services/logistics_api_client.rb
class LogisticsApiClient
  # Cambia esto por la URL real de tu app de logística en producción/desarrollo
  BASE_URL = ENV["LOGISTICS_API_URL"]

  def fetch_delivery(id)
    response = @connection.get("deliveries/#{id}")
    response.success? ? response.body : nil
  end

  def self.fetch_deliveries(filters = {})
    new.fetch_deliveries(filters)
  end

  def initialize
    @connection = Faraday.new(url: BASE_URL) do |f|
      f.request :json
      f.response :json
      f.adapter Faraday.default_adapter
      # Si usas SSL local con certificados auto-firmados:
      f.ssl[:verify] = false
    end
  end

  def fetch_deliveries(filters = {})
    response = @connection.get("deliveries", {
      from: filters[:from],
      to: filters[:to],
      status: filters[:status],
      order_number: filters[:order_number], # Si agregas este filtro en la API
      seller_code: filters[:seller_code]    # Si agregas este filtro en la API
    })

    if response.success?
      response.body
    else
      Rails.logger.error "Error consultando Logística: #{response.status} - #{response.body}"
      []
    end
  rescue Faraday::Error => e
    Rails.logger.error "Error de conexión con Logística: #{e.message}"
    []
  end
end
