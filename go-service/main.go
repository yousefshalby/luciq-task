package main

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
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

	// Verify application exists
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

	// Get next chat number atomically from Redis
	redisKey := fmt.Sprintf("application:%s:chat_counter", token)
	chatNumber, err := redisClient.Incr(ctx, redisKey).Result()
	if err != nil {
		log.Printf("Redis error: %v", err)
		respondError(w, http.StatusInternalServerError, "Internal server error")
		return
	}

	// Queue chat creation job to Sidekiq for async processing
	// This improves performance under high traffic by offloading work to background jobs
	err = enqueueSidekiqJob("CreateChatJob", []interface{}{token, int(chatNumber)})
	if err != nil {
		log.Printf("Failed to enqueue job: %v", err)
		respondError(w, http.StatusInternalServerError, "Internal server error")
		return
	}

	log.Printf("Chat %d queued for creation for application %s", chatNumber, token)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusAccepted)
	json.NewEncoder(w).Encode(ChatResponse{
		Number: int(chatNumber),
		Status: "Chat is being processed",
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

	// Verify chat exists and get its ID
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

	// Get next message number atomically from Redis
	redisKey := fmt.Sprintf("chat:%d:message_counter", chatID)
	messageNumber, err := redisClient.Incr(ctx, redisKey).Result()
	if err != nil {
		log.Printf("Redis error: %v", err)
		respondError(w, http.StatusInternalServerError, "Internal server error")
		return
	}

	// Queue message creation job to Sidekiq for async processing
	err = enqueueSidekiqJob("CreateMessageJob", []interface{}{chatID, int(messageNumber), req.Message.Body})
	if err != nil {
		log.Printf("Failed to enqueue job: %v", err)
		respondError(w, http.StatusInternalServerError, "Internal server error")
		return
	}

	log.Printf("Message %d queued for creation for chat %d", messageNumber, chatID)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusAccepted)
	json.NewEncoder(w).Encode(MessageResponse{
		Number: int(messageNumber),
		Status: "Message is being processed",
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

// enqueueSidekiqJob pushes a job to Sidekiq's Redis queue
// This allows Go service to leverage Rails' background job processing
func enqueueSidekiqJob(jobClass string, args []interface{}) error {
	// Sidekiq job format
	job := map[string]interface{}{
		"class": jobClass,
		"args":  args,
		"retry": true,
		"queue": "default",
		"jid":   generateJID(),
		"created_at": time.Now().Unix(),
		"enqueued_at": time.Now().Unix(),
	}

	jobJSON, err := json.Marshal(job)
	if err != nil {
		return fmt.Errorf("failed to marshal job: %w", err)
	}

	// Push to Sidekiq's queue in Redis
	err = redisClient.LPush(ctx, "queue:default", string(jobJSON)).Err()
	if err != nil {
		return fmt.Errorf("failed to push job to Redis: %w", err)
	}

	return nil
}

// generateJID generates a unique job ID for Sidekiq (24 character hex string)
func generateJID() string {
	b := make([]byte, 12) // 12 bytes = 24 hex characters
	rand.Read(b)
	return hex.EncodeToString(b)
}

