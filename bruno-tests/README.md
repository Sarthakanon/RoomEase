# RoomEase API Tests - Bruno Collection

This Bruno collection contains comprehensive API tests for the RoomEase backend authentication system.

## Setup Instructions

### 1. Install Bruno
Download and install Bruno from [https://www.usebruno.com/](https://www.usebruno.com/)

### 2. Import Collection
1. Open Bruno
2. Click "Open Collection"
3. Navigate to this `bruno-tests` directory
4. Select the folder to import the collection

### 3. Quick Setup (Recommended)
Run the automated setup script:
```bash
cd bruno-tests/scripts
./setup.sh
```

This script will:
- Check dependencies
- Test backend connectivity
- Help you choose the right environment
- Generate Firebase tokens
- Configure environment variables

### 4. Manual Configuration

#### Choose Your Environment
Select the appropriate environment file:
- **Local.bru**: Local development server (`http://192.168.101.9:8080`)
- **Docker.bru**: Docker containerized backend (`http://localhost:8080`)
- **Production.bru**: Railway deployment (`https://your-app.up.railway.app`)
- **AWS.bru**: AWS App Runner deployment (`https://your-aws-url.amazonaws.com`)

#### Update Environment Variables
Edit your chosen environment file and update:
- `baseUrl`: Your backend server URL
- `firebase_token`: A valid Firebase ID token for testing

### 5. Getting Firebase Token

#### Option A: Use Helper Script
```bash
cd bruno-tests/scripts
npm install
npm run get-token
```

#### Option B: From Your App
1. Login to your RoomEase app
2. Open browser developer tools
3. Copy the Firebase token from network requests

#### Option C: Create Test User
1. Go to Firebase Console > Authentication > Users
2. Add user: `test@example.com` / `testpassword123`
3. Use helper script to generate token

### 6. Verify Setup
1. Start your backend server
2. Run the "Login" test in Bruno
3. Check that session variables are populated

## Test Structure

### Authentication Tests (`Auth/` folder)

1. **Login.bru** - Valid login with Firebase token
   - Tests successful authentication
   - Validates response structure
   - Stores session data in environment variables

2. **Login - Invalid Token.bru** - Login with invalid token
   - Tests error handling for invalid tokens
   - Validates 401 response

3. **Login - Missing Token.bru** - Login without token
   - Tests request validation
   - Validates 400 response

4. **Verify Session.bru** - Check session validity
   - Tests session verification with valid cookie
   - Validates user data in response

5. **Verify Session - No Cookie.bru** - Verify without session
   - Tests behavior when no session cookie provided
   - Should return valid: false

6. **Verify Session - Invalid Cookie.bru** - Verify with invalid session
   - Tests behavior with invalid session cookie
   - Should return valid: false

7. **Refresh Session.bru** - Extend session expiration
   - Tests session refresh functionality
   - Validates new expiration time

8. **Refresh Session - No Cookie.bru** - Refresh without session
   - Tests error handling when no session provided
   - Validates 401 response

9. **Logout.bru** - End user session
   - Tests successful logout
   - Clears environment variables

10. **Logout - No Cookie.bru** - Logout without session
    - Tests error handling when no session provided
    - Validates 401 response

## Running Tests

### Run All Tests
1. Select the collection in Bruno
2. Click "Run Collection" button
3. Choose environment (Local/Production)
4. Click "Run"

### Run Individual Tests
1. Navigate to specific test file
2. Click "Send" button
3. Review response and test results

### Test Sequence
For best results, run tests in this order:
1. Login (to establish session)
2. Verify Session
3. Refresh Session
4. Logout

## Expected Responses

### Successful Login
```json
{
  "user_id": "firebase_uid_string",
  "email": "user@example.com",
  "session_id": "session_id_string"
}
```

### Session Verification (Valid)
```json
{
  "valid": true,
  "user_id": "firebase_uid_string",
  "email": "user@example.com"
}
```

### Session Verification (Invalid)
```json
{
  "valid": false
}
```

### Session Refresh
```json
{
  "message": "Session refreshed successfully",
  "expires_at": "2024-01-01T12:00:00Z"
}
```

### Logout
```json
{
  "message": "Logged out successfully"
}
```

### Error Response
```json
{
  "error": "Error message description"
}
```

## Authentication Flow

1. **Login**: POST `/api/auth/login` with Firebase token
2. **Session Cookie**: Server sets `session_id` cookie (HttpOnly)
3. **Protected Requests**: Include session cookie in subsequent requests
4. **Session Validation**: Server validates cookie and checks user ban status
5. **Logout**: POST `/api/auth/logout` to invalidate session

## Backend Endpoints Tested

- `POST /api/auth/login` - User authentication
- `GET /api/auth/verify` - Session validation
- `POST /api/auth/refresh` - Session extension
- `POST /api/auth/logout` - Session termination

## Notes

- All protected endpoints require valid session cookie
- Sessions expire after 24 hours
- User ban status is checked on each request
- Firebase token verification happens server-side
- Session data is stored in-memory (development)

## Troubleshooting

### Common Issues

1. **401 Unauthorized**: Check if Firebase token is valid and not expired
2. **400 Bad Request**: Verify request body format and required fields
3. **403 Forbidden**: User account may be banned
4. **500 Internal Server Error**: Check backend logs and database connectivity

### Debug Tips

1. Check Bruno console for detailed error messages
2. Verify environment variables are set correctly
3. Ensure backend server is running and accessible
4. Check Firebase configuration and service account
5. Verify database connectivity for user operations

## Contributing

When adding new tests:
1. Follow the naming convention: `Feature - Test Case.bru`
2. Include proper assertions and test descriptions
3. Update this README with new test documentation
4. Ensure tests are independent and can run in any order