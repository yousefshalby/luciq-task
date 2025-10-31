require 'sidekiq'
require 'sidekiq-scheduler'

Sidekiq.configure_server do |config|
  config.redis = { url: ENV["REDIS_URL"] || "redis://redis:6379/1" }
  
  # Load the scheduler
  config.on(:startup) do
    Sidekiq.schedule = YAML.load_file(File.expand_path('../../sidekiq.yml', __FILE__))[:scheduler][:schedule]
    SidekiqScheduler::Scheduler.instance.reload_schedule!
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV["REDIS_URL"] || "redis://redis:6379/1" }
end
