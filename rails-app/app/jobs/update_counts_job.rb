class UpdateCountsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting count update job"

    Application.find_each do |application|
      actual_count = application.chats.count
      if application.chats_count != actual_count
        application.update_column(:chats_count, actual_count)
        Rails.logger.info "Updated chats_count for application #{application.token}: #{actual_count}"
      end
    end

    Chat.find_each do |chat|
      actual_count = chat.messages.count
      if chat.messages_count != actual_count
        chat.update_column(:messages_count, actual_count)
        Rails.logger.info "Updated messages_count for chat #{chat.id}: #{actual_count}"
      end
    end

    Rails.logger.info "Count update job completed"
  end
end

