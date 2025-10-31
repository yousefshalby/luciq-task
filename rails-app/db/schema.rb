ActiveRecord::Schema[7.1].define(version: 2024_10_30_000001) do
  create_table "applications", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.string "token"
    t.integer "chats_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_applications_on_created_at"
    t.index ["token"], name: "index_applications_on_token", unique: true
  end

  create_table "chats", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "application_id", null: false
    t.integer "number"
    t.integer "messages_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["application_id", "number"], name: "index_chats_on_application_id_and_number", unique: true
    t.index ["application_id"], name: "index_chats_on_application_id"
    t.index ["created_at"], name: "index_chats_on_created_at"
  end

  create_table "messages", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "chat_id", null: false
    t.integer "number"
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["body"], name: "index_messages_on_body", type: :fulltext
    t.index ["chat_id", "number"], name: "index_messages_on_chat_id_and_number", unique: true
    t.index ["chat_id"], name: "index_messages_on_chat_id"
    t.index ["created_at"], name: "index_messages_on_created_at"
  end

  add_foreign_key "chats", "applications"
  add_foreign_key "messages", "chats"
end
