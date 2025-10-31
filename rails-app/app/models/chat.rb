class Chat < ApplicationRecord
  belongs_to :application
  has_many :messages, dependent: :destroy

  validates :number, presence: true, uniqueness: { scope: :application_id }
  validates :application, presence: true

  def next_message_number
    redis_key = "chat:#{id}:message_counter"
    REDIS.incr(redis_key)
  end

  def sync_message_counter_to_redis
    max_number = messages.maximum(:number) || 0
    redis_key = "chat:#{id}:message_counter"
    REDIS.set(redis_key, max_number)
  end
end
