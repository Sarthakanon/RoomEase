# Design Document

## Overview

This document describes the architecture and design for integrating a Go backend server with the existing Flutter + Firebase application. The backend will handle session management while Firebase continues to manage authentication.

## Architecture

```
┌─────────────────┐
│  Flutter App    │
│  (Mobile)       │
└────────┬────────┘
         │
         │ 1. Firebase Auth (Login/Signup)
         │ 2. Get Firebase Token
         │
         ▼
┌─────────────────┐         ┌──────────────────┐
│  Firebase Auth  │◄────────┤   Go Backend     │
│  (Google)       │ Verify  │   Server         │
└─────────────────┘  Token  └────────┬─────────┘
                                     │
         ┌───────────────────────────┼───────────────────┐
         │                           │                   │
         ▼                           ▼                   ▼
┌─────────────────┐         ┌──────────────┐   ┌──────────────┐
│   Firestore     │         │   MongoDB    │   │   API        │
│   (Flutter)     │         │   Database   │   │   Handlers   │
└─────────────────┘         └──────────────┘   └──────────────┘
                            (Sessions, Users,
                             Roomspaces)
```

## Components and Interfaces

### 1. Go Backend Structure

```
backend/
├── main.go                 # Entry point
├── go.mod                  # Go modules
├── go.sum                  # Dependencies checksum
├── .env                    # Environment variables
├── config/
│   ├── config.go          # Configuration loader
│   └── firebase.go        # Firebase initialization
├── middleware/
│   ├── auth.go            # Session validation middleware
│   ├── cors.go            # CORS middleware
│   └── logger.go          # Request logging middleware
├── handlers/
│   ├── auth.go            # Authentication endpoints
│   ├── user.go            # User endpoints
│   └── roomspace.go       # Roomspace endpoints
├── models/
│   ├── user.go            # User model
│   ├── roomspace.go       # Roomspace model
│   └── session.go         # Session model
├── services/
│   ├── firebase.go        # Firebase token verification
│   ├── session.go         # Session management
│   └── mongodb.go         # MongoDB operations
└── utils/
    ├── response.go        # Response helpers
    └── errors.go          # Error handling
```

### 2. MongoDB Database

**Collections:**
- `users` - User profiles synced from Firebase
- `roomspaces` - Roomspace data
- `sessions` - Active user sessions

**Session Structure:**
```go
type Session struct {
    ID        primitive.ObjectID `bson:"_id,omitempty"`
    SessionID string             `bson:"sessionId"`
    UserID    string             `bson:"userId"`
    Email     string             `bson:"email"`
    CreatedAt time.Time          `bson:"createdAt"`
    ExpiresAt time.Time          `bson:"expiresAt"`
}
```

**Session Store Interface:**
```go
type SessionStore interface {
    Create(userID, email string) (*Session, error)
    Get(sessionID string) (*Session, error)
    Delete(sessionID string) error
    Cleanup() // Remove expired sessions
}
```

### 3. API Endpoints

#### Authentication Endpoints

**POST /api/auth/login**
- Request: `{ "firebaseToken": "string" }`
- Response: `{ "user": {...}, "sessionID": "string" }`
- Sets session cookie

**POST /api/auth/logout**
- Request: Session cookie
- Response: `{ "message": "Logged out successfully" }`
- Clears session cookie

**GET /api/auth/verify**
- Request: Session cookie
- Response: `{ "user": {...}, "valid": true }`

**POST /api/auth/refresh**
- Request: Session cookie
- Response: `{ "expiresAt": "timestamp" }`
- Extends session expiration

#### Protected Endpoints (Require Session)

**GET /api/user/profile**
- Get current user profile from MongoDB

**GET /api/roomspaces**
- Get user's roomspaces from MongoDB

**POST /api/roomspaces**
- Create new roomspace in MongoDB

**POST /api/roomspaces/:id/join**
- Join existing roomspace in MongoDB

**POST /api/sync/user**
- Sync user data from Firestore to MongoDB

### 4. Flutter Integration

**New Service: `lib/services/api_service.dart`**

```dart
class ApiService {
  final String baseUrl;
  final Dio _dio;
  
  // Login with Firebase token
  Future<void> login(String firebaseToken);
  
  // Logout
  Future<void> logout();
  
  // Verify session
  Future<bool> verifySession();
  
  // Make authenticated requests
  Future<Response> get(String path);
  Future<Response> post(String path, dynamic data);
}
```

**Cookie Management:**
- Use `dio_cookie_manager` package
- Store cookies persistently
- Include cookies in all requests

### 5. Firebase Admin SDK Setup

**Service Account:**
- Download service account JSON from Firebase Console
- Store as `backend/config/serviceAccountKey.json`
- Add to `.gitignore`

**Initialization:**
```go
app, err := firebase.NewApp(context.Background(), &firebase.Config{
    ProjectID: "your-project-id",
}, option.WithCredentialsFile("config/serviceAccountKey.json"))
```

## Data Models

### User Model (Go)
```go
type User struct {
    ID        string    `json:"id" firestore:"id"`
    Name      string    `json:"name" firestore:"name"`
    Email     string    `json:"email" firestore:"email"`
    PhotoURL  string    `json:"photoUrl,omitempty" firestore:"photoUrl,omitempty"`
    CreatedAt time.Time `json:"createdAt" firestore:"createdAt"`
}
```

### Roomspace Model (Go)
```go
type Roomspace struct {
    ID        string    `json:"id" firestore:"id"`
    Name      string    `json:"name" firestore:"name"`
    Code      string    `json:"code" firestore:"code"`
    AdminID   string    `json:"adminId" firestore:"adminId"`
    MemberIDs []string  `json:"memberIds" firestore:"memberIds"`
    CreatedAt time.Time `json:"createdAt" firestore:"createdAt"`
}
```

## Error Handling

**Standard Error Response:**
```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable message",
    "details": {}
  }
}
```

**Error Codes:**
- `UNAUTHORIZED`: Invalid or missing session
- `INVALID_TOKEN`: Firebase token verification failed
- `NOT_FOUND`: Resource not found
- `VALIDATION_ERROR`: Invalid request data
- `INTERNAL_ERROR`: Server error

## Testing Strategy

### Unit Tests
- Session management functions
- Token verification logic
- Firestore operations
- Request/response helpers

### Integration Tests
- API endpoint testing
- Firebase Admin SDK integration
- Session flow (login → request → logout)

### Manual Testing
- Flutter app → Backend communication
- Session persistence across app restarts
- Token refresh flow
- Error scenarios

## Security Considerations

1. **HTTPS Only**: Use HTTPS in production
2. **Secure Cookies**: Set HttpOnly, Secure, SameSite flags
3. **Token Validation**: Always verify Firebase tokens
4. **Session Expiration**: Default 7 days, configurable
5. **Rate Limiting**: Prevent abuse of endpoints
6. **Input Validation**: Validate all request data
7. **CORS**: Restrict to known origins

## Environment Variables

```env
# Server
PORT=8080
ENV=development

# Firebase
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_SERVICE_ACCOUNT_PATH=./config/serviceAccountKey.json

# Session
SESSION_SECRET=your-secret-key
SESSION_TIMEOUT=168h  # 7 days

# CORS
ALLOWED_ORIGINS=http://localhost:*,https://yourdomain.com

# Logging
LOG_LEVEL=info
```

## Deployment Considerations

1. **Docker**: Containerize Go backend
2. **Cloud Run**: Deploy to Google Cloud Run
3. **Environment**: Use Cloud Secret Manager for credentials
4. **Monitoring**: Add health check endpoint `/health`
5. **Logging**: Use structured logging (JSON format)
