class AddAdditionalIndices < ActiveRecord::Migration[7.0]
  def change
    add_index :applications, :created_at
    add_index :chats, :created_at
    add_index :messages, :created_at
    
    add_index :messages, :body, type: :fulltext if ActiveRecord::Base.connection.adapter_name == 'Mysql2'
  end
end

