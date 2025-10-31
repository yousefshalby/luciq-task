class ChatSerializer < ActiveModel::Serializer
  # Only expose number (not ID) for client identification
  attributes :number, :messages_count
end
