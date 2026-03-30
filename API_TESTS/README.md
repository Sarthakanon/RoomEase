# RoomEase API Tests

This folder contains comprehensive API test files for all RoomEase backend endpoints. These can be imported into Bruno, Postman, Insomnia, or any REST API testing tool.

## 📁 Test File Organization

### Authentication APIs
- `01_auth_tests.json` - Login, logout, session management

### User Management APIs  
- `02_user_tests.json` - User profile management, roomspace count

### Roomspace APIs
- `03_roomspace_tests.json` - Create, join, manage roomspaces, invite codes

### Expense APIs
- `04_expense_tests.json` - Shared & personal expenses, different split types

### Analytics APIs
- `05_analytics_tests.json` - AI analytics, predictions, recommendations, patterns

### Balance & Settlement APIs
- `06_balance_tests.json` - Balance calculations, settlements, suggestions

### Payment APIs
- `07_payment_tests.json` - Payment confirmations, notifications, history

### Notification APIs
- `08_notification_tests.json` - Notifications, join requests, reminders

### Admin APIs
- `09_admin_tests.json` - User management, banning, system statistics

### Health Check
- `10_health_tests.json` - Health check endpoint, system status

## 🔧 Setup Instructions

### For Bruno App:
1. Open Bruno
2. Create new collection: "RoomEase API Tests"
3. Import each JSON file as a separate folder
4. Update environment variables (see below)

### For Postman:
1. Open Postman
2. Import → File → Select JSON files
3. Set up environment variables

### For Insomnia:
1. Open Insomnia
2. Import Data → From File → Select JSON files
3. Configure environment

## 🌍 Environment Variables

Set these variables in your API testing tool:

```
BASE_URL=http://localhost:8080
FIREBASE_TOKEN=your_firebase_id_token
SESSION_ID=your_session_cookie
USER_ID=your_firebase_uid
ROOMSPACE_ID=your_test_roomspace_id
EXPENSE_ID=your_test_expense_id
```

## 📋 Testing Workflow

### 1. Authentication Flow
1. Run `01_auth_tests.json` → Login
2. Copy `session_id` from response cookies
3. Set `SESSION_ID` environment variable

### 2. User Setup
1. Run `02_user_tests.json` → Get/Update Profile
2. Run `03_roomspace_tests.json` → Create Roomspace
3. Copy `roomspace_id` and set `ROOMSPACE_ID`

### 3. Core Features
1. Run `04_expense_tests.json` → Test expense management
2. Run `06_analytics_tests.json` → Test analytics
3. Run `07_balance_tests.json` → Test balance calculations

### 4. Advanced Features
1. Run `08_payment_tests.json` → Test payment system
2. Run `09_notification_tests.json` → Test notifications
3. Run `10_admin_tests.json` → Test admin features

## 🔍 Test Data

Each test file includes:
- ✅ **Valid requests** with expected responses
- ❌ **Invalid requests** to test error handling
- 🔒 **Authentication tests** for protected endpoints
- 📊 **Edge cases** and boundary conditions

## 🚨 Important Notes

1. **Order Matters**: Run authentication tests first to get session cookies
2. **Environment Setup**: Update BASE_URL for your backend server
3. **Test Data**: Some tests require existing data (users, roomspaces, expenses)
4. **Cleanup**: Some tests create data - clean up after testing
5. **Rate Limiting**: Space out requests if you have rate limiting enabled

## 🛠️ Customization

To customize for your environment:

1. **Update URLs**: Change `BASE_URL` in environment variables
2. **Update Test Data**: Modify request bodies with your test data
3. **Add New Tests**: Follow the existing pattern to add new endpoints
4. **Authentication**: Update Firebase token generation method

## 📊 Expected Results

Each test includes expected:
- **Status Codes**: 200, 201, 400, 401, 403, 404, 500
- **Response Format**: JSON structure and required fields
- **Error Messages**: Specific error responses for validation

## 🔄 Continuous Testing

These tests can be used for:
- **Manual Testing**: Run individual requests during development
- **Integration Testing**: Verify API changes don't break functionality
- **Documentation**: Serve as API documentation with examples
- **Debugging**: Isolate issues with specific endpoints

Happy Testing! 🚀