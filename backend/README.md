# RoomEase Backend

Go backend server for RoomEase application.

## Features
- Firebase Authentication integration
- MongoDB database
- Session management
- RESTful API

## Setup

1. Install Go 1.21 or higher
2. Install dependencies:
   ```bash
   go mod download
   ```

3. Create `.env` file (see `.env.example`)

4. Run the server:
   ```bash
   go run main.go
   ```

## Analytics V2 Bridge (Required For ML Insights)

The analytics endpoints call an ML bridge at `ML_API_URL` (default `http://localhost:5001`).

Start the V2 bridge from project root:

```bash
cd dataset-sarthak-ai
pip install -r requirements.txt
./start_ml_bridge_v2.sh
```

Then run backend:

```bash
cd backend
go run main.go
```

The V2 bridge now runs in strict mode: if model dependencies or model files are missing, the bridge will fail to start (no dummy/fallback inference).

## Project Structure

```
backend/
├── main.go              # Entry point
├── config/              # Configuration
├── handlers/            # HTTP handlers
├── middleware/          # Middleware
├── models/              # Data models
├── services/            # Business logic
└── utils/               # Utilities
```

## API Endpoints

### Authentication
- `POST /api/auth/login` - Login with Firebase token
- `POST /api/auth/logout` - Logout
- `GET /api/auth/verify` - Verify session
- `POST /api/auth/refresh` - Refresh session

### User
- `GET /api/user/profile` - Get user profile
- `PUT /api/user/profile` - Update user profile

### Roomspace
- `GET /api/roomspaces` - Get user's roomspaces
- `POST /api/roomspaces` - Create roomspace
- `POST /api/roomspaces/:id/join` - Join roomspace
- `GET /api/roomspaces/:id` - Get roomspace details
