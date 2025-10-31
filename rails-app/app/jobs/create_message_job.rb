class CreateMessageJob < ApplicationJob
  queue_as :default

  def perform(chat_id, message_number, body)
    chat = Chat.find_by(id: chat_id)

    unless chat
      Rails.logger.error "Chat with ID #{chat_id} not found"
      return
    end

    begin
      message = chat.messages.create!(
        number: message_number,
        body: body
      )

      Rails.logger.info "Message #{message_number} created for chat #{chat_id}"
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to create message: #{e.message}"
    end
  end
end
