# Django Backend - Already Implemented

The Django backend at `/Users/kripaskhatiwada/gyaanai_backend` is fully configured.

## Setup Instructions

### 1. Start Django Server
```bash
cd /Users/kripaskhatiwada/gyaanai_backend
source venv/bin/activate
python manage.py runserver 0.0.0.0:8000
```

### 2. Model File Location
The model file is symlinked at:
```
/Users/kripaskhatiwada/gyaanai_backend/models/gemma-4-E2B-it.litertlm
```

## Available API Endpoints

### Health Check
```
GET /api/health/
```
Returns: `{"status": "ok", "timestamp": "..."}`

### Model Info
```
GET /api/ai/model/info/
```
Returns:
```json
{
  "name": "gemma-4-E2B-it",
  "version": "1.0.0",
  "size_bytes": 2583085056,
  "download_url": "http://localhost:8000/api/ai/model/download/",
  "checksum_sha256": "",
  "updated_at": "..."
}
```

### Model Download
```
GET /api/ai/model/download/
```
- Supports HTTP Range headers for resume
- Returns the model file (~2.4GB)

### AI Chat Streaming
```
POST /api/ai/chat/stream/
```
Request:
```json
{
  "grade": 5,
  "subject": "math",
  "message": "What is 2+2?",
  "system_prompt": "optional custom prompt"
}
```
Response: Server-Sent Events (SSE)
```
data: {"token": "The"}
data: {"token": " answer"}
data: {"token": " is"}
data: {"done": true, "total_tokens": 5}
```

### Sync Endpoints (for offline data)
```
POST /api/ai/sync/chat-session/   # Sync chat sessions
POST /api/ai/sync/chat-message/   # Sync individual messages
POST /api/progress/sync/          # Sync user progress
POST /api/quiz/sync/result/       # Sync quiz results
```

## Flutter App Configuration

Update Django URL in Flutter app settings:
- Default: `http://127.0.0.1:8000`
- For physical device: Use your computer's IP address

## Flow

### Online Mode
1. App checks `/api/health/` - if reachable, use online mode
2. Chat requests go to `/api/ai/chat/stream/`
3. No model download needed

### Offline Mode
1. App checks `/api/health/` - if unreachable, check local model
2. If no local model, prompt user to download from `/api/ai/model/download/`
3. After download, use local Gemma model for inference
4. When back online, sync offline data to server

## Requirements

Make sure Ollama is running for online AI:
```bash
ollama serve
ollama pull gemma4:4b
```
