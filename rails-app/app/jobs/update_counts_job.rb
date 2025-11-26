class UpdateCountsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting count update job"

    # Use atomic SQL UPDATE with subquery to avoid race conditions
    # This ensures the count is calculated and updated in a single atomic operation
    
    # Update application chats_count
    sql = <<-SQL
      UPDATE applications
      SET chats_count = (
        SELECT COUNT(*) 
        FROM chats 
        WHERE chats.application_id = applications.id
      )
      WHERE chats_count != (
        SELECT COUNT(*) 
        FROM chats 
        WHERE chats.application_id = applications.id
      )
    SQL
    
    updated_apps = ActiveRecord::Base.connection.execute(sql).affected_rows
    Rails.logger.info "Updated chats_count for #{updated_apps} applications"

    # Update chat messages_count
    sql = <<-SQL
      UPDATE chats
      SET messages_count = (
        SELECT COUNT(*) 
        FROM messages 
        WHERE messages.chat_id = chats.id
      )
      WHERE messages_count != (
        SELECT COUNT(*) 
        FROM messages 
        WHERE messages.chat_id = chats.id
      )
    SQL
    
    updated_chats = ActiveRecord::Base.connection.execute(sql).affected_rows
    Rails.logger.info "Updated messages_count for #{updated_chats} chats"

    Rails.logger.info "Count update job completed"
  end
end

