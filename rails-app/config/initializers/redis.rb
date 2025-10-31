# Initialize Redis connection for atomic counters
# Used for race-condition-free chat and message numbering
REDIS = Redis.new(
  url: ENV["REDIS_URL"] || "redis://redis:6379/0",
  timeout: 5,
  reconnect_attempts: 3
)

# Test connection
begin
  REDIS.ping
  Rails.logger.info "Redis connection established successfully"
rescue Redis::CannotConnectError => e
  Rails.logger.error "Failed to connect to Redis: #{e.message}"
end

