class CreateChatJob < ApplicationJob
  queue_as :default

  def perform(application_token, chat_number)
    application = Application.find_by(token: application_token)

    unless application
      Rails.logger.error "Application with token #{application_token} not found"
      return
    end

    begin
      chat = application.chats.create!(
        number: chat_number
      )
      
      # Initialize the message counter in Redis for this new chat
      chat.sync_message_counter_to_redis

      Rails.logger.info "Chat #{chat_number} created for application #{application_token}"
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to create chat: #{e.message}"
    end
  end
end

