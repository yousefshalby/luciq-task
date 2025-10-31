# Configure ElasticSearch client for message search
Elasticsearch::Model.client = Elasticsearch::Client.new(
  host: ENV["ELASTICSEARCH_URL"] || "http://elasticsearch:9200",
  log: Rails.env.development?,
  transport_options: {
    request: { timeout: 5 }
  }
)

# Test connection and log status
begin
  if Elasticsearch::Model.client.ping
    Rails.logger.info "ElasticSearch connection established successfully"
  end
rescue => e
  Rails.logger.error "ElasticSearch connection failed: #{e.message}"
end
