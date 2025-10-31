class ChatSerializer < ActiveModel::Serializer
  attributes :number, :messages_count
end
