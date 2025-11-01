# Chat System API

A high-performance, scalable chat system API built with Ruby on Rails and Go, designed to handle concurrent requests across multiple servers.

## Features

- **RESTful API** for managing applications, chats, and messages
- **Microservices Architecture** with Go handling high-performance write operations
- **Race condition handling** using Redis atomic counters
- **Asynchronous message processing** with Sidekiq for high throughput
- **ElasticSearch integration** for efficient message search with partial matching
- **Auto-incrementing numbers** for chats and messages (not database IDs)
- **Hourly count updates** for chats_count and messages_count columns
- **Optimized database indices** for fast queries
- **Fully containerized** with Docker Compose


### Services Overview


1. **Rails API Service** (Port 3000)
  

2. **Go Service** (Port 8080) - **Bonus Feature**
  

Both services:
- Connect to the same MySQL database
- Use shared Redis for atomic counters
- Maintain data consistency across services

### Technology Stack

- **Ruby on Rails 7.0** - API framework for reads/updates
- **Go 1.21** - High-performance service for write operations (bonus)
- **MySQL 8.0** - Primary datastore (shared)
- **Redis 7** - Atomic counters and Sidekiq queue (shared)
- **Sidekiq** - Background job processing
- **ElasticSearch 8.9** - Full-text search engine
- **Docker & Docker Compose** - Containerization


## Getting Started

### Prerequisites

- Docker
- Docker Compose

### Installation & Running

1. Clone the repository
2. 
3. Start the entire stack:
   ```bash
   docker-compose up --build
   ```
## API Endpoints

### Service Port Assignment

- **Rails API**: `http://localhost:3000` - All GET, PUT/PATCH operations
- **Go Service**: `http://localhost:8080` - POST operations for chats and messages (bonus)

### Applications (Rails - Port 3000)

| Method | Endpoint | Description | Service |
|--------|----------|-------------|---------|
| GET | `/applications` | List all applications | Rails |
| POST | `/applications` | Create new application (auto-generates token) | Rails |
| GET | `/applications/:token` | Get application by token | Rails |
| PUT/PATCH | `/applications/:token` | Update application name | Rails |

**Request Example (Create)**:
```bash
curl -X POST http://localhost:3000/applications \
  -H "Content-Type: application/json" \
  -d '{"application": {"name": "My App"}}'
```

**Response**:
```json
{
  "name": "My App",
  "token": "a1b2c3d4e5f6g7h8i9j0",
  "chats_count": 0
}
```

### Chats

| Method | Endpoint | Description | Service |
|--------|----------|-------------|---------|
| GET | `/applications/:token/chats` | List all chats in application | Rails |
| POST | `/applications/:token/chats` | Create new chat (auto-generates number) | **Go** |
| GET | `/applications/:token/chats/:number` | Get specific chat | Rails |
| PUT/PATCH | `/applications/:token/chats/:number` | Update chat | Rails |

**Request Example (Create with Go Service)**:
```bash
curl -X POST http://localhost:8080/applications/a1b2c3d4e5f6g7h8i9j0/chats \
  -H "Content-Type: application/json" \
  -d '{"chat": {}}'
```

**Response** (201 Created):
```json
{
  "number": 1,
  "status": "Chat created successfully"
}
```

### Messages

| Method | Endpoint | Description | Service |
|--------|----------|-------------|---------|
| GET | `/applications/:token/chats/:number/messages` | List all messages in chat | Rails |
| POST | `/applications/:token/chats/:number/messages` | Create new message | **Go** |
| GET | `/applications/:token/chats/:number/messages/:number` | Get specific message | Rails |
| PUT/PATCH | `/applications/:token/chats/:number/messages/:number` | Update message | Rails |
| GET | `/applications/:token/chats/:number/messages/search?query=text` | Search messages | Rails |

**Request Example (Create with Go Service)**:
```bash
curl -X POST http://localhost:8080/applications/a1b2c3d4e5f6g7h8i9j0/chats/1/messages \
  -H "Content-Type: application/json" \
  -d '{"message": {"body": "Hello, World!"}}'
```

**Response** (201 Created):
```json
{
  "number": 1,
  "status": "Message created successfully"
}
```

**Search Example**:
```bash
curl "http://localhost:3000/applications/a1b2c3d4e5f6g7h8i9j0/chats/1/messages/search?query=hello"
```

**Response**:
```json
[
  {
    "number": 1,
    "body": "Hello, World!"
  }
]
```

## Database Schema

### Applications Table
- `id` (primary key)
- `name` (string, required)
- `token` (string, unique, indexed, auto-generated)
- `chats_count` (integer, default: 0, updated hourly)
- `created_at`, `updated_at`

**Indices**: `token` (unique), `created_at`

### Chats Table
- `id` (primary key)
- `application_id` (foreign key)
- `number` (integer, unique per application)
- `messages_count` (integer, default: 0, updated hourly)
- `created_at`, `updated_at`

**Indices**: `[application_id, number]` (unique composite), `created_at`

### Messages Table
- `id` (primary key)
- `chat_id` (foreign key)
- `number` (integer, unique per chat)
- `body` (text, required)
- `created_at`, `updated_at`

**Indices**: `[chat_id, number]` (unique composite), `created_at`

## Go Service (Bonus)

### Overview

The Go service is a high-performance microservice built with Go 1.21 that handles write-intensive operations (chat and message creation). It provides:



### Go Service Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/applications/:token/chats` | POST | Create a new chat |
| `/applications/:token/chats/:number/messages` | POST | Create a new message |

```bash

# Create a chat
curl -X POST http://localhost:8080/applications/{TOKEN}/chats \
  -H "Content-Type: application/json" \
  -d '{"chat": {}}'

# Create a message
curl -X POST http://localhost:8080/applications/{TOKEN}/chats/1/messages \
  -H "Content-Type: application/json" \
  -d '{"message": {"body": "Test message"}}'
```


