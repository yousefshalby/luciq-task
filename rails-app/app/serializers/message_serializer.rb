class MessageSerializer < ActiveModel::Serializer
  # Only expose number (not ID) for client identification
  attributes :number, :body
end
