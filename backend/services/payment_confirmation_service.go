package services

import (
	"fmt"
	"roomease/backend/models"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// PaymentConfirmationService handles payment confirmation operations
type PaymentConfirmationService struct {
	db             *gorm.DB
	balanceService *BalanceService
	dbService      *PostgresService
}

// NewPaymentConfirmationService creates a new payment confirmation service
func NewPaymentConfirmationService(db *gorm.DB, balanceService *BalanceService, dbService *PostgresService) *PaymentConfirmationService {
	return &PaymentConfirmationService{
		db:             db,
		balanceService: balanceService,
		dbService:      dbService,
	}
}

// CreatePaymentConfirmation creates a new payment confirmation claim
func (s *PaymentConfirmationService) CreatePaymentConfirmation(pc *models.PaymentConfirmation) error {
	// Validate payment confirmation
	if err := pc.Validate(); err != nil {
		return err
	}

	// Verify both users are members of the roomspace
	if err := s.verifyRoomspaceMembership(pc.RoomspaceID, pc.FromUserID); err != nil {
		return fmt.Errorf("payer is not a member of roomspace: %w", err)
	}
	if err := s.verifyRoomspaceMembership(pc.RoomspaceID, pc.ToUserID); err != nil {
		return fmt.Errorf("recipient is not a member of roomspace: %w", err)
	}

	// Set initial status
	pc.Status = models.PaymentStatusPending

	// Create payment confirmation
	if err := s.db.Create(pc).Error; err != nil {
		return fmt.Errorf("failed to create payment confirmation: %w", err)
	}

	// Send notification to recipient
	if err := s.sendPaymentNotification(pc); err != nil {
		// Log error but don't fail the operation
		fmt.Printf("Warning: failed to send payment notification: %v\n", err)
	}

	return nil
}

// ConfirmPayment confirms a payment (only recipient can confirm)
func (s *PaymentConfirmationService) ConfirmPayment(paymentID uint, confirmerUserID string) (*models.PaymentConfirmation, error) {
	var payment models.PaymentConfirmation
	
	// Get payment with lock to prevent race conditions
	if err := s.db.Clauses(clause.Locking{Strength: "UPDATE"}).First(&payment, paymentID).Error; err != nil {
		return nil, fmt.Errorf("payment not found: %w", err)
	}

	// Verify confirmer is the recipient
	if payment.ToUserID != confirmerUserID {
		return nil, models.ErrUnauthorized
	}

	// Check if already confirmed or rejected
	if payment.IsConfirmed() {
		return nil, models.ErrAlreadyConfirmed
	}
	if payment.IsRejected() {
		return nil, models.ErrAlreadyRejected
	}

	// Start transaction for atomic balance update
	err := s.db.Transaction(func(tx *gorm.DB) error {
		// Update payment status
		now := time.Now()
		payment.Status = models.PaymentStatusConfirmed
		payment.ConfirmedAt = &now
		payment.ConfirmedBy = &confirmerUserID

		if err := tx.Save(&payment).Error; err != nil {
			return fmt.Errorf("failed to update payment status: %w", err)
		}

		// Create settlement record
		settlement := &models.Settlement{
			RoomspaceID: payment.RoomspaceID,
			FromUserID:  payment.FromUserID,
			ToUserID:    payment.ToUserID,
			Amount:      payment.Amount,
			Notes:       fmt.Sprintf("Payment confirmed: %s", payment.Notes),
			SettledAt:   payment.PaymentDate,
		}

		if err := tx.Create(settlement).Error; err != nil {
			return fmt.Errorf("failed to create settlement: %w", err)
		}

		// Update balances
		// When FromUser pays ToUser:
		// - FromUser's balance increases (they paid their debt)
		// - ToUser's balance decreases (they received what they were owed)
		
		// Update FromUser balance (increase)
		if err := tx.Exec(`
			UPDATE user_balances 
			SET balance = balance + ?,
			    total_paid = total_paid + ?,
			    last_updated = ?
			WHERE user_id = ? AND roomspace_id = ?
		`, payment.Amount, payment.Amount, now, payment.FromUserID, payment.RoomspaceID).Error; err != nil {
			return fmt.Errorf("failed to update payer balance: %w", err)
		}

		// Update ToUser balance (decrease)
		if err := tx.Exec(`
			UPDATE user_balances 
			SET balance = balance - ?,
			    last_updated = ?
			WHERE user_id = ? AND roomspace_id = ?
		`, payment.Amount, now, payment.ToUserID, payment.RoomspaceID).Error; err != nil {
			return fmt.Errorf("failed to update recipient balance: %w", err)
		}

		return nil
	})

	if err != nil {
		return nil, err
	}

	// Refresh balance cache
	if err := s.balanceService.UpdateBalanceCache(payment.RoomspaceID); err != nil {
		// Log error but don't fail the operation
		fmt.Printf("Warning: failed to update balance cache: %v\n", err)
	}

	// Send confirmation notification to payer
	if err := s.sendConfirmationNotification(&payment); err != nil {
		// Log error but don't fail the operation
		fmt.Printf("Warning: failed to send confirmation notification: %v\n", err)
	}

	return &payment, nil
}

// RejectPayment rejects a payment claim (only recipient can reject)
func (s *PaymentConfirmationService) RejectPayment(paymentID uint, rejecterUserID string, reason string) (*models.PaymentConfirmation, error) {
	var payment models.PaymentConfirmation
	
	// Get payment
	if err := s.db.First(&payment, paymentID).Error; err != nil {
		return nil, fmt.Errorf("payment not found: %w", err)
	}

	// Verify rejecter is the recipient
	if payment.ToUserID != rejecterUserID {
		return nil, models.ErrUnauthorized
	}

	// Check if already confirmed or rejected
	if payment.IsConfirmed() {
		return nil, models.ErrAlreadyConfirmed
	}
	if payment.IsRejected() {
		return nil, models.ErrAlreadyRejected
	}

	// Update payment status
	payment.Status = models.PaymentStatusRejected
	payment.RejectionReason = reason

	if err := s.db.Save(&payment).Error; err != nil {
		return nil, fmt.Errorf("failed to update payment status: %w", err)
	}

	// Send rejection notification to payer
	if err := s.sendRejectionNotification(&payment); err != nil {
		// Log error but don't fail the operation
		fmt.Printf("Warning: failed to send rejection notification: %v\n", err)
	}

	return &payment, nil
}

// GetPendingConfirmations gets pending payment confirmations for a user
func (s *PaymentConfirmationService) GetPendingConfirmations(roomspaceID, userID string) ([]models.PaymentConfirmation, error) {
	var payments []models.PaymentConfirmation
	
	// Get payments where user is either payer or recipient and status is pending
	err := s.db.
		Preload("FromUser").
		Preload("ToUser").
		Where("roomspace_id = ? AND status = ? AND (from_user_id = ? OR to_user_id = ?)",
			roomspaceID, models.PaymentStatusPending, userID, userID).
		Order("created_at DESC").
		Find(&payments).Error

	if err != nil {
		return nil, fmt.Errorf("failed to get pending confirmations: %w", err)
	}

	return payments, nil
}

// GetPaymentHistory gets payment history with filters
func (s *PaymentConfirmationService) GetPaymentHistory(filter models.PaymentHistoryFilter) ([]models.PaymentConfirmation, error) {
	var payments []models.PaymentConfirmation
	
	query := s.db.Preload("FromUser").Preload("ToUser")

	// Apply filters
	if filter.RoomspaceID != "" {
		query = query.Where("roomspace_id = ?", filter.RoomspaceID)
	}
	if filter.UserID != "" {
		query = query.Where("from_user_id = ? OR to_user_id = ?", filter.UserID, filter.UserID)
	}
	if filter.Status != "" {
		query = query.Where("status = ?", filter.Status)
	}
	if filter.StartDate != nil {
		query = query.Where("payment_date >= ?", filter.StartDate)
	}
	if filter.EndDate != nil {
		query = query.Where("payment_date <= ?", filter.EndDate)
	}

	// Apply pagination
	if filter.Limit > 0 {
		query = query.Limit(filter.Limit)
	}
	if filter.Offset > 0 {
		query = query.Offset(filter.Offset)
	}

	// Order by most recent first
	query = query.Order("payment_date DESC, created_at DESC")

	if err := query.Find(&payments).Error; err != nil {
		return nil, fmt.Errorf("failed to get payment history: %w", err)
	}

	return payments, nil
}

// GetPaymentByID gets a payment confirmation by ID
func (s *PaymentConfirmationService) GetPaymentByID(paymentID uint) (*models.PaymentConfirmation, error) {
	var payment models.PaymentConfirmation
	
	if err := s.db.Preload("FromUser").Preload("ToUser").First(&payment, paymentID).Error; err != nil {
		return nil, fmt.Errorf("payment not found: %w", err)
	}

	return &payment, nil
}

// GetPaymentStats gets payment statistics for a roomspace
func (s *PaymentConfirmationService) GetPaymentStats(roomspaceID string) (map[string]interface{}, error) {
	var stats struct {
		TotalConfirmed int64
		TotalPending   int64
		TotalRejected  int64
		TotalAmount    float64
	}

	// Count confirmed payments
	s.db.Model(&models.PaymentConfirmation{}).
		Where("roomspace_id = ? AND status = ?", roomspaceID, models.PaymentStatusConfirmed).
		Count(&stats.TotalConfirmed)

	// Count pending payments
	s.db.Model(&models.PaymentConfirmation{}).
		Where("roomspace_id = ? AND status = ?", roomspaceID, models.PaymentStatusPending).
		Count(&stats.TotalPending)

	// Count rejected payments
	s.db.Model(&models.PaymentConfirmation{}).
		Where("roomspace_id = ? AND status = ?", roomspaceID, models.PaymentStatusRejected).
		Count(&stats.TotalRejected)

	// Sum confirmed payment amounts
	s.db.Model(&models.PaymentConfirmation{}).
		Where("roomspace_id = ? AND status = ?", roomspaceID, models.PaymentStatusConfirmed).
		Select("COALESCE(SUM(amount), 0)").
		Scan(&stats.TotalAmount)

	return map[string]interface{}{
		"total_confirmed": stats.TotalConfirmed,
		"total_pending":   stats.TotalPending,
		"total_rejected":  stats.TotalRejected,
		"total_amount":    stats.TotalAmount,
	}, nil
}

// verifyRoomspaceMembership checks if a user is a member of a roomspace
func (s *PaymentConfirmationService) verifyRoomspaceMembership(roomspaceID, userID string) error {
	var count int64
	err := s.db.Model(&models.RoomspaceMember{}).
		Where("roomspace_id = ? AND user_id = ? AND is_active = ?",
			roomspaceID, userID, true).
		Count(&count).Error

	if err != nil {
		return fmt.Errorf("failed to verify membership: %w", err)
	}

	if count == 0 {
		return fmt.Errorf("user is not a member of roomspace")
	}

	return nil
}

// sendPaymentNotification sends a notification when a payment is created
func (s *PaymentConfirmationService) sendPaymentNotification(payment *models.PaymentConfirmation) error {
	// Get user names
	fromUser, err := s.dbService.GetUserByFirebaseUID(payment.FromUserID)
	if err != nil {
		return err
	}

	// Create notification for recipient
	notification := &models.Notification{
		RecipientUID: payment.ToUserID,
		Type:         "PAYMENT_CLAIM",
		Title:        "Payment Confirmation Request",
		Message:      fmt.Sprintf("%s claims to have paid you Rs.%.2f. Please confirm or reject.", fromUser.Name, payment.Amount),
		Data:         fmt.Sprintf(`{"payment_id":%d,"roomspace_id":"%s","amount":%.2f}`, payment.ID, payment.RoomspaceID, payment.Amount),
	}

	return s.dbService.CreateNotification(notification)
}

// sendConfirmationNotification sends a notification when a payment is confirmed
func (s *PaymentConfirmationService) sendConfirmationNotification(payment *models.PaymentConfirmation) error {
	// Get user names
	toUser, err := s.dbService.GetUserByFirebaseUID(payment.ToUserID)
	if err != nil {
		return err
	}

	// Create notification for payer
	notification := &models.Notification{
		RecipientUID: payment.FromUserID,
		Type:         "PAYMENT_CONFIRMED",
		Title:        "Payment Confirmed",
		Message:      fmt.Sprintf("%s confirmed receiving Rs.%.2f from you. Your balance has been updated.", toUser.Name, payment.Amount),
		Data:         fmt.Sprintf(`{"payment_id":%d,"roomspace_id":"%s","amount":%.2f}`, payment.ID, payment.RoomspaceID, payment.Amount),
	}

	return s.dbService.CreateNotification(notification)
}

// sendRejectionNotification sends a notification when a payment is rejected
func (s *PaymentConfirmationService) sendRejectionNotification(payment *models.PaymentConfirmation) error {
	// Get user names
	toUser, err := s.dbService.GetUserByFirebaseUID(payment.ToUserID)
	if err != nil {
		return err
	}

	message := fmt.Sprintf("%s rejected your payment claim of Rs.%.2f.", toUser.Name, payment.Amount)
	if payment.RejectionReason != "" {
		message += fmt.Sprintf(" Reason: %s", payment.RejectionReason)
	}

	// Create notification for payer
	notification := &models.Notification{
		RecipientUID: payment.FromUserID,
		Type:         "PAYMENT_REJECTED",
		Title:        "Payment Rejected",
		Message:      message,
		Data:         fmt.Sprintf(`{"payment_id":%d,"roomspace_id":"%s","amount":%.2f,"reason":"%s"}`, payment.ID, payment.RoomspaceID, payment.Amount, payment.RejectionReason),
	}

	return s.dbService.CreateNotification(notification)
}
