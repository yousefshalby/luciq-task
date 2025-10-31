class ApplicationSerializer < ActiveModel::Serializer
  attributes :name, :token, :chats_count
end
