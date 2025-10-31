namespace :elasticsearch do
  namespace :import do
    desc "Import data from a model into ElasticSearch"
    task model: :environment do
      unless ENV['CLASS']
        puts "Usage: rails elasticsearch:import:model CLASS='Message' FORCE=y"
        exit
      end

      klass = ENV['CLASS'].constantize
      force = ENV['FORCE'] == 'y'

      puts "Importing #{klass.name} into ElasticSearch..."

      begin
        if force
          klass.__elasticsearch__.create_index! force: true
        else
          klass.__elasticsearch__.create_index! unless klass.__elasticsearch__.index_exists?
        end

        klass.import
        puts "Successfully imported #{klass.count} records"
      rescue => e
        puts "Error: #{e.message}"
        puts "Make sure ElasticSearch is running and accessible"
      end
    end
  end

  namespace :index do
    desc "Delete ElasticSearch index"
    task delete: :environment do
      unless ENV['CLASS']
        puts "Usage: rails elasticsearch:index:delete CLASS='Message'"
        exit
      end

      klass = ENV['CLASS'].constantize
      puts "Deleting index for #{klass.name}..."

      begin
        klass.__elasticsearch__.delete_index!
        puts "Successfully deleted index"
      rescue => e
        puts "Error: #{e.message}"
      end
    end
  end
end

