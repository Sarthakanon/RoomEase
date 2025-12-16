# Implementation Plan

## Backend Setup Tasks

- [x] 1. Initialize Go backend project



  - Create `backend/` directory in project root
  - Initialize Go modules with `go mod init`
  - Create project structure (config, handlers, middleware, models, services, utils)
  - _Requirements: 1.1, 1.2, 1.3_

- [x] 2. Setup Firebase Admin SDK


  - [x] 2.1 Install Firebase Admin SDK dependency


    - Add `firebase.google.com/go/v4` to go.mod
    - _Requirements: 2.1_
  
  - [x] 2.2 Create Firebase configuration


    - Create `config/firebase.go` with Firebase initialization
    - Load service account from JSON file
    - Export Firebase Auth and Firestore clients
    - _Requirements: 2.1, 2.4_
  
  - [x] 2.3 Implement token verification


    - Create `services/firebase.go` with VerifyToken function
    - Extract user ID and email from verified token
    - Handle verification errors
    - _Requirements: 2.2, 2.3, 2.5_

- [x] 3. Implement session management


  - [x] 3.1 Create session models


    - Define Session struct in `models/session.go`
    - Define SessionStore interface
    - _Requirements: 3.1, 3.2_
  
  - [x] 3.2 Implement in-memory session store


    - Create `services/session.go` with in-memory store
    - Implement Create, Get, Delete methods
    - Add cleanup goroutine for expired sessions
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_
  
  - [x] 3.3 Create session middleware


    - Create `middleware/auth.go` for session validation
    - Extract session from cookie
    - Attach user info to request context
    - _Requirements: 3.3, 5.1, 5.2, 5.3, 5.4_

- [x] 4. Create authentication endpoints


  - [x] 4.1 Implement login endpoint


    - Create `handlers/auth.go` with Login handler
    - Verify Firebase token
    - Create session and set cookie
    - Return user information
    - _Requirements: 4.1, 4.2_
  
  - [x] 4.2 Implement logout endpoint


    - Add Logout handler to delete session
    - Clear session cookie
    - _Requirements: 4.3_
  
  - [x] 4.3 Implement verify endpoint


    - Add Verify handler to check session validity
    - Return user info if valid
    - _Requirements: 4.4_
  
  - [x] 4.4 Implement refresh endpoint


    - Add Refresh handler to extend session
    - Update expiration time
    - _Requirements: 4.5_

- [x] 5. Setup server and middleware


  - [x] 5.1 Create main server


    - Create `main.go` with Gin server setup
    - Load configuration from environment
    - Register routes and middleware
    - _Requirements: 1.2, 1.4_
  
  - [x] 5.2 Implement CORS middleware


    - Create `middleware/cors.go`
    - Configure allowed origins, methods, headers
    - Enable credentials
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_
  
  - [x] 5.3 Implement logging middleware


    - Create `middleware/logger.go`
    - Log request method, path, user ID
    - Log response status and duration
    - _Requirements: 9.3, 9.4_

- [x] 6. Create protected API endpoints


  - [x] 6.1 Implement user endpoints



    - Create `handlers/user.go`
    - Add GET /api/user/profile endpoint
    - Fetch user data from PostgreSQL


    - _Requirements: 5.1, 5.3, 5.4, 7.1_
  
  - [ ] 6.2 Implement roomspace endpoints
    - Create `handlers/roomspace.go`
    - Add GET /api/roomspaces endpoint
    - Add POST /api/roomspaces endpoint
    - Add POST /api/roomspaces/:id/join endpoint
    - _Requirements: 5.1, 5.3, 5.4, 7.2, 7.4_

- [x] 7. Add PostgreSQL operations




  - [x] 7.1 Create PostgreSQL service


    - Create `services/postgres.go`
    - Implement GetUser, CreateUser, UpdateUser
    - Implement GetRoomspace, CreateRoomspace, GetUserRoomspaces
    - Create database models with GORM
    - Implement auto-migration
    - _Requirements: 7.1, 7.2, 7.3, 7.4_
  

  - [x] 7.2 Add data validation
    - Validate user data before writing
    - Validate roomspace data before writing
    - _Requirements: 7.3_

- [x] 8. Setup configuration and utilities

  - [x] 8.1 Create configuration loader

    - Create `config/config.go`
    - Load from .env file using godotenv
    - Define Config struct with all settings
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_
  
  - [x] 8.2 Create response helpers


    - Create `utils/response.go`
    - Add JSON response functions
    - Add error response function
    - _Requirements: 9.2_
  
  - [x] 8.3 Create error handling utilities


    - Create `utils/errors.go`
    - Define error types and codes


    - Add error logging with context
    - _Requirements: 9.1, 9.2, 9.5_

- [ ] 9. Create environment configuration







  - Create `.env.example` file with all variables
  - Document each environment variable


  - Add `.env` to `.gitignore`
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

## Flutter Integration Tasks



- [ ] 10. Add HTTP client dependencies
  - Add `dio` package to pubspec.yaml

  - Add `dio_cookie_manager` for cookie handling
  - Add `cookie_jar` for cookie persistence
  - _Requirements: 6.2_

- [ ] 11. Create API service
  - [ ] 11.1 Create ApiService class
    - Create `lib/services/api_service.dart`
    - Initialize Dio with base URL
    - Setup cookie manager
    - _Requirements: 6.1, 6.2_
  
  - [ ] 11.2 Implement authentication methods
    - Add login(firebaseToken) method
    - Add logout() method
    - Add verifySession() method
    - _Requirements: 6.1, 6.2, 6.3_
  
  - [ ] 11.3 Add request methods
    - Add get(path) method with session cookie
    - Add post(path, data) method with session cookie
    - Add error handling for 401 responses
    - _Requirements: 6.3, 6.4_

- [x] 12. Update authentication flow


  - [x] 12.1 Update login screen



    - After Firebase login, call backend login API
    - Store session cookie
    - Handle backend errors
    - _Requirements: 6.1_


  
  - [ ] 12.2 Update signup screen
    - After Firebase signup, call backend login API


    - Store session cookie
    - _Requirements: 6.1_
  
  - [ ] 12.3 Update logout flow
    - Call backend logout API before Firebase signout
    - Clear session cookie
    - _Requirements: 6.5_

- [ ] 13. Add session verification
  - Check session validity on app startup
  - Refresh Firebase token if session invalid
  - Retry backend login with new token
  - _Requirements: 6.4_

## Testing and Documentation Tasks

- [ ]* 14. Write backend tests
  - [ ]* 14.1 Unit tests for session management
  - [ ]* 14.2 Unit tests for token verification
  - [ ]* 14.3 Integration tests for API endpoints

- [ ]* 15. Create API documentation
  - Document all endpoints with examples
  - Create Postman collection
  - Add README for backend setup

- [ ] 16. Setup deployment
  - Create Dockerfile for Go backend
  - Add health check endpoint
  - Document deployment steps
