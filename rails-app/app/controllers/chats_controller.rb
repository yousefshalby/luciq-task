class ChatsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_application
  before_action :set_chat, only: [:show, :update]

  
  def index
    chats = @application.chats.order(number: :asc)
    render json: chats, each_serializer: ChatSerializer
  end


  def create
    # Get the next chat number from Redis (atomic operation)
    chat_number = @application.next_chat_number
    
    # Queue the chat creation in background job for better performance under high traffic
    CreateChatJob.perform_later(@application.token, chat_number)
    
    render json: { 
      number: chat_number, 
      status: "Chat is being processed" 
    }, status: :accepted
  end

  def show
    render json: @chat, serializer: ChatSerializer
  end

  def update
    render json: @chat, serializer: ChatSerializer
  end

  private

  def set_application
    @application = Application.find_by(token: params[:application_id])
    unless @application
      render json: { error: "Application not found" }, status: :not_found
    end
  end

  def set_chat
    @chat = @application.chats.find_by(number: params[:id])
    unless @chat
      render json: { error: "Chat not found" }, status: :not_found
    end
  end
end
