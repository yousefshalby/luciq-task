class AddAdditionalIndices < ActiveRecord::Migration[7.0]
  def change
    # Only adding fulltext index for message search functionality
    # Removed created_at indices as they add overhead without clear benefit
    add_index :messages, :body, type: :fulltext if ActiveRecord::Base.connection.adapter_name == 'Mysql2'
  end
end

