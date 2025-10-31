class MessagesController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_application_and_chat

  
  def index
    messages = @chat.messages.order(number: :asc)
    render json: messages, each_serializer: MessageSerializer
  end


  def create
    
    message_number = @chat.next_message_number
    
    CreateMessageJob.perform_async(@chat.id, message_number, message_params[:body])
    
    render json: { 
      number: message_number, 
      status: "Message is being processed" 
    }, status: :accepted
  end

  def show
    message = @chat.messages.find_by(number: params[:id])
    
    if message
      render json: message, serializer: MessageSerializer
    else
      render json: { error: "Message not found or still being processed" }, status: :not_found
    end
  end

  def update
    message = @chat.messages.find_by(number: params[:id])
    
    if message
      if message.update(message_params)
        message.__elasticsearch__.index_document
        render json: message, serializer: MessageSerializer
      else
        render json: { errors: message.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { error: "Message not found" }, status: :not_found
    end
  end

  def search
    query = params[:query]
    
    if query.blank?
      render json: { error: "Query parameter is required" }, status: :bad_request
      return
    end

    begin 
      search_results = Message.search_messages(@chat.id, query)
      messages = search_results.records.to_a
      
      render json: messages, each_serializer: MessageSerializer
    rescue => e
      Rails.logger.error "ElasticSearch error: #{e.message}"
      render json: { error: "Search temporarily unavailable" }, status: :service_unavailable
    end
  end

  private

  def set_application_and_chat
    @application = Application.find_by(token: params[:application_id])
    unless @application
      render json: { error: "Application not found" }, status: :not_found and return
    end

    @chat = @application.chats.find_by(number: params[:chat_id])
    unless @chat
      render json: { error: "Chat not found" }, status: :not_found and return
    end
  end

  def message_params
    params.require(:message).permit(:body)
  end
end
