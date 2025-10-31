class Message < ApplicationRecord
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks

  belongs_to :chat

  validates :number, presence: true, uniqueness: { scope: :chat_id }
  validates :body, presence: true
  validates :chat, presence: true

  settings index: { 
    number_of_shards: 1,
    analysis: {
      analyzer: {
        ngram_analyzer: {
          type: "custom",
          tokenizer: "ngram_tokenizer",
          filter: ["lowercase"]
        },
        ngram_search_analyzer: {
          type: "custom",
          tokenizer: "standard",
          filter: ["lowercase"]
        }
      },
      tokenizer: {
        ngram_tokenizer: {
          type: "ngram",
          min_gram: 3,
          max_gram: 4,
          token_chars: ["letter", "digit"]
        }
      }
    }
  } do
    mappings dynamic: false do
      indexes :body, type: :text, analyzer: "ngram_analyzer", search_analyzer: "ngram_search_analyzer"
      indexes :chat_id, type: :integer
      indexes :number, type: :integer
      indexes :created_at, type: :date
    end
  end

  def as_indexed_json(options = {})
    as_json(only: [:body, :chat_id, :number, :created_at])
  end

  def self.search_messages(chat_id, query)
    search({
      query: {
        bool: {
          must: [
            { term: { chat_id: chat_id } },
            { match: { body: query } }
          ]
        }
      },
      sort: [{ number: { order: "asc" } }]
    })
  end
end

