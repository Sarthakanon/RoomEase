# RoomEase API Testing with Bruno

This folder contains Bruno API test collection for RoomEase backend.

## Installation

Bruno has been installed via snap:
```bash
sudo snap install bruno
```

## Opening the Collection

1. Open Bruno application:
```bash
bruno
```

2. Click "Open Collection" and select the `bruno` folder in this directory

3. Or from terminal:
```bash
bruno ~/RoomEase-API-Tests/bruno
```

## Environment Setup

The collection includes a `local` environment with variables:
- `base_url`: http://localhost:8080
- `roomspace_id`: 3ce5eb29-004e-42ab-9034-5106e627a44a
- `user_id`: 4i9FNTKBwae1soC1qX06fFad4cI2
- `other_user_id`: 8XOUJPSzqXV7IH5AS9df0RPIn1a2

To use different values, edit `environments/local.bru`

## API Endpoints

### Balance
- **Get Balances** - Fetch current balances for all users in roomspace
- **Get Settlement Suggestions** - Get suggested payments to settle balances

### Payments
- **Create Payment Confirmation** - Mark a payment as paid
- **Get Pending Payments** - Get all pending payment confirmations
- **Confirm Payment** - Confirm a payment (recipient confirms)
- **Reject Payment** - Reject a payment claim
- **Get Payment History** - Get all payments (confirmed, rejected, pending)

### Notifications
- **Send Payment Reminder** - Send reminder to user to pay
- **Get Notifications** - Get all notifications

### Expenses
- **Get Expenses** - Get all expenses in roomspace

## Testing Workflow

### 1. Check Current Balances
1. Go to Balance → Get Balances
2. Click Send
3. View response to see current balances

### 2. Create Payment
1. Go to Payments → Create Payment Confirmation
2. Modify the request body if needed:
   - `to_user_id`: Who is receiving the payment
   - `amount`: Payment amount
   - `payment_type`: FULL or PARTIAL
   - `payment_date`: When payment was made
3. Click Send
4. Note the payment ID from response

### 3. Confirm Payment
1. Go to Payments → Confirm Payment
2. Update the URL with the payment ID from step 2
3. Click Send
4. Check response for confirmation

### 4. Verify Balance Updated
1. Go to Balance → Get Balances
2. Click Send
3. Verify balance has changed

### 5. Check Settlement Suggestions
1. Go to Balance → Get Settlement Suggestions
2. Click Send
3. View remaining payments needed

## Common Issues

### Connection Refused
- Ensure backend is running: `go run main.go` in backend folder
- Check backend is on port 8080

### 404 Not Found
- Verify roomspace_id and payment_id are correct
- Check URL path is correct

### 401 Unauthorized
- Some endpoints may require authentication
- Check if session cookie is being sent

## Tips

1. **Use Variables**: Click on variables in request to auto-fill values
2. **Save Responses**: Right-click response to save for reference
3. **Test Collections**: Use the play button to run all requests in sequence
4. **View History**: Check request history to see all previous requests
5. **Pretty Print**: Response is automatically formatted for readability

## Backend API Documentation

For complete API documentation, see:
- `backend/EXPENSE_API_ENDPOINTS.md`
- `backend/handlers/` - Source code for all endpoints

## Troubleshooting

### Payment not confirming
1. Check payment status is PENDING
2. Verify you're using correct payment ID
3. Check backend logs for errors

### Balance not updating
1. Ensure payment is CONFIRMED (not just PENDING)
2. Pull down to refresh in app
3. Check database: `SELECT * FROM settlements;`

### Notifications not appearing
1. Check notification was created: `SELECT * FROM notifications;`
2. Verify recipient_uid matches user_id
3. Refresh notification screen in app

## Next Steps

1. Test the complete payment flow
2. Verify balance calculations
3. Check notification delivery
4. Test edge cases (partial payments, multiple payments, etc.)

## Resources

- [Bruno Documentation](https://docs.usebruno.com/)
- [RoomEase Backend README](../../backend/README.md)
- [API Endpoints Documentation](../../backend/EXPENSE_API_ENDPOINTS.md)
