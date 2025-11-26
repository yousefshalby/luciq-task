class RemoveCreatedAtIndices < ActiveRecord::Migration[7.0]
  def change
    remove_index :applications, :created_at if index_exists?(:applications, :created_at)
    remove_index :chats, :created_at if index_exists?(:chats, :created_at)
    remove_index :messages, :created_at if index_exists?(:messages, :created_at)
  end
end

