package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/go-redis/redis/v8"
	"github.com/gorilla/mux"
)

var (
	db          *sql.DB
	redisClient *redis.Client
	ctx         = context.Background()
)

type ChatRequest struct {
	Chat struct {
	} `json:"chat"`
}

type MessageRequest struct {
	Message struct {
		Body string `json:"body"`
	} `json:"message"`
}

type ErrorResponse struct {
	Error  string   `json:"error,omitempty"`
	Errors []string `json:"errors,omitempty"`
}

type ChatResponse struct {
	Number int    `json:"number"`
	Status string `json:"status"`
}

type MessageResponse struct {
	Number int    `json:"number"`
	Status string `json:"status"`
}

func main() {
	initDB()
	initRedis()
	defer cleanup()

	router := mux.NewRouter()
	router.HandleFunc("/applications/{token}/chats", createChat).Methods("POST")
	router.HandleFunc("/applications/{token}/chats/{number}/messages", createMessage).Methods("POST")


	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Go service starting on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, router))
}

func initDB() {
	var err error
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?parseTime=true",
		getEnv("MYSQL_USER", "root"),
		getEnv("MYSQL_PASSWORD", "password"),
		getEnv("MYSQL_HOST", "mysql"),
		getEnv("MYSQL_PORT", "3306"),
		getEnv("MYSQL_DATABASE", "chat_system_development"),
	)

	db, err = sql.Open("mysql", dsn)
	if err != nil {
		log.Fatal("Failed to connect to MySQL:", err)
	}

	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(25)
	db.SetConnMaxLifetime(5 * time.Minute)

	// Wait for DB to be ready
	for i := 0; i < 30; i++ {
		if err = db.Ping(); err == nil {
			log.Println("Connected to MySQL")
			return
		}
		log.Printf("Waiting for MySQL... (%d/30)", i+1)
		time.Sleep(2 * time.Second)
	}
	log.Fatal("Failed to connect to MySQL after retries:", err)
}

func initRedis() {
	redisURL := getEnv("REDIS_URL", "redis://redis:6379/1")
	opt, err := redis.ParseURL(redisURL)
	if err != nil {
		log.Fatal("Failed to parse Redis URL:", err)
	}

	redisClient = redis.NewClient(opt)

	for i := 0; i < 30; i++ {
		if err = redisClient.Ping(ctx).Err(); err == nil {
			log.Println("Connected to Redis")
			return
		}
		log.Printf("Waiting for Redis... (%d/30)", i+1)
		time.Sleep(2 * time.Second)
	}
	log.Fatal("Failed to connect to Redis after retries:", err)
}


func createChat(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	token := vars["token"]

	var appID int
	err := db.QueryRow("SELECT id FROM applications WHERE token = ?", token).Scan(&appID)
	if err == sql.ErrNoRows {
		respondError(w, http.StatusNotFound, "Application not found")
		return
	}
	if err != nil {
		log.Printf("Database error: %v", err)
		respondError(w, http.StatusInternalServerError, "Internal server error")
		return
	}

	var req ChatRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	redisKey := fmt.Sprintf("application:%s:chat_counter", token)
	chatNumber, err := redisClient.Incr(ctx, redisKey).Result()
	if err != nil {
		log.Printf("Redis error: %v", err)
		respondError(w, http.StatusInternalServerError, "Internal server error")
		return
	}

	result, err := db.Exec(
		"INSERT INTO chats (application_id, number, messages_count, created_at, updated_at) VALUES (?, ?, 0, NOW(), NOW())",
		appID, chatNumber,
	)
	if err != nil {
		log.Printf("Database insert error: %v", err)
		respondError(w, http.StatusInternalServerError, "Internal server error")
		return
	}

	chatID, err := result.LastInsertId()
	if err != nil {
		log.Printf("Failed to get last insert ID: %v", err)
	} else {
		messageRedisKey := fmt.Sprintf("chat:%d:message_counter", chatID)
		redisClient.Set(ctx, messageRedisKey, 0, 0)
	}

	log.Printf("Chat %d created successfully for application %s", chatNumber, token)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(ChatResponse{
		Number: int(chatNumber),
		Status: "Chat created successfully",
	})
}

func createMessage(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	token := vars["token"]
	chatNumberStr := vars["number"]

	chatNumber, err := strconv.Atoi(chatNumberStr)
	if err != nil {
		respondError(w, http.StatusBadRequest, "Invalid chat number")
		return
	}

	var chatID int
	query := `
		SELECT c.id 
		FROM chats c 
		INNER JOIN applications a ON c.application_id = a.id 
		WHERE a.token = ? AND c.number = ?
	`
	err = db.QueryRow(query, token, chatNumber).Scan(&chatID)
	if err == sql.ErrNoRows {
		respondError(w, http.StatusNotFound, "Chat not found")
		return
	}
	if err != nil {
		log.Printf("Database error: %v", err)
		respondError(w, http.StatusInternalServerError, "Internal server error")
		return
	}

	var req MessageRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	if req.Message.Body == "" {
		respondErrors(w, http.StatusUnprocessableEntity, []string{"Body can't be blank"})
		return
	}

	redisKey := fmt.Sprintf("chat:%d:message_counter", chatID)
	messageNumber, err := redisClient.Incr(ctx, redisKey).Result()
	if err != nil {
		log.Printf("Redis error: %v", err)
		respondError(w, http.StatusInternalServerError, "Internal server error")
		return
	}

	_, err = db.Exec(
		"INSERT INTO messages (chat_id, number, body, created_at, updated_at) VALUES (?, ?, ?, NOW(), NOW())",
		chatID, messageNumber, req.Message.Body,
	)
	if err != nil {
		log.Printf("Database insert error: %v", err)
		respondError(w, http.StatusInternalServerError, "Internal server error")
		return
	}

	log.Printf("Message %d created successfully for chat %d", messageNumber, chatID)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(MessageResponse{
		Number: int(messageNumber),
		Status: "Message created successfully",
	})
}

func respondError(w http.ResponseWriter, status int, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(ErrorResponse{Error: message})
}

func respondErrors(w http.ResponseWriter, status int, messages []string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(ErrorResponse{Errors: messages})
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func cleanup() {
	if db != nil {
		db.Close()
	}
	if redisClient != nil {
		redisClient.Close()
	}
}

