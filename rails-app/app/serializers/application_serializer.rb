class ApplicationSerializer < ActiveModel::Serializer
  # Only expose token (not ID) for client identification
  attributes :name, :token, :chats_count
end
