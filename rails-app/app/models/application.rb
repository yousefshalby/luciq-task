class Application < ApplicationRecord
  has_many :chats, dependent: :destroy
  
  validates :name, presence: true
  validates :token, presence: true, uniqueness: true

  before_create :generate_token

  def next_chat_number
    redis_key = "application:#{token}:chat_counter"
    REDIS.incr(redis_key)
  end

  def sync_chat_counter_to_redis
    max_number = chats.maximum(:number) || 0
    redis_key = "application:#{token}:chat_counter"
    REDIS.set(redis_key, max_number)
  end

  private

  def generate_token
    self.token ||= SecureRandom.hex(10)
  end
end
