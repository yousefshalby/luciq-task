class ChatsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_application
  before_action :set_chat, only: [:show, :update]

  
  def index
    chats = @application.chats.order(number: :asc)
    render json: chats, each_serializer: ChatSerializer
  end


  def create
    chat_number = @application.next_chat_number
    
    chat = @application.chats.new(number: chat_number)
    
    if chat.save
      chat.sync_message_counter_to_redis
      render json: chat, status: :created, serializer: ChatSerializer
    else
      chat_number = @application.next_chat_number
      chat = @application.chats.new(number: chat_number)
      
      if chat.save
        chat.sync_message_counter_to_redis
        render json: chat, status: :created, serializer: ChatSerializer
      else
        render json: { errors: chat.errors.full_messages }, status: :unprocessable_entity
      end
    end
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
