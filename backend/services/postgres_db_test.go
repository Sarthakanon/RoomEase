package services

import (
	"roomease/backend/models"
	"roomease/backend/testutils"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestPostgresService_DBExpenseIsolationAndSoftDelete(t *testing.T) {
	db := testutils.RequireTestDB(t)
	fixtures := testutils.SeedCore(t, db)
	service := NewPostgresService()

	roomID := fixtures.Roomspace.ID.String()
	require.NoError(t, service.ValidateRoomspaceMembership(fixtures.Member.FirebaseUID, roomID))
	require.Error(t, service.ValidateRoomspaceMembership(fixtures.Outsider.FirebaseUID, roomID))

	userExpenses, err := service.GetUserExpenses(fixtures.Member.FirebaseUID, roomID, 20, 0)
	require.NoError(t, err)
	require.Len(t, userExpenses, 2)
	for _, expense := range userExpenses {
		assert.Equal(t, roomID, expense.RoomspaceID)
		assert.NotEqual(t, fixtures.DeletedExpense.ID, expense.ID)
		assert.NotEqual(t, "Other Room Expense", expense.Title)
		assert.NotEmpty(t, expense.Splits)
	}

	require.NoError(t, service.DeleteExpense(fixtures.EqualExpense.ID))
	roomExpenses, err := service.GetRoomspaceExpenses(roomID, 20, 0, 0, 0)
	require.NoError(t, err)
	require.Len(t, roomExpenses, 1)
	assert.Equal(t, fixtures.ExactExpense.ID, roomExpenses[0].ID)

	var deleted models.Expense
	require.NoError(t, db.Unscoped().First(&deleted, fixtures.EqualExpense.ID).Error)
	assert.True(t, deleted.DeletedAt.Valid)
}

func TestBalanceService_DBCalculatesCacheAndSettlement(t *testing.T) {
	db := testutils.RequireTestDB(t)
	fixtures := testutils.SeedCore(t, db)
	service := NewBalanceService()
	roomID := fixtures.Roomspace.ID.String()

	summary, err := service.CalculateRoomspaceBalances(roomID)
	require.NoError(t, err)
	assert.InDelta(t, 420.0, summary.TotalExpenses, 0.01)
	assert.Equal(t, 2, summary.ExpenseCount)
	assert.InDelta(t, 70.0, summary.UserBalances[fixtures.Creator.FirebaseUID], 0.01)
	assert.InDelta(t, -70.0, summary.UserBalances[fixtures.Member.FirebaseUID], 0.01)

	suggestions, err := service.GenerateSettlementSuggestions(roomID)
	require.NoError(t, err)
	require.Len(t, suggestions, 1)
	assert.Equal(t, fixtures.Member.FirebaseUID, suggestions[0].FromUserID)
	assert.Equal(t, fixtures.Creator.FirebaseUID, suggestions[0].ToUserID)
	assert.InDelta(t, 70.0, suggestions[0].Amount, 0.01)

	require.NoError(t, service.CreateSettlement(&models.Settlement{
		RoomspaceID: roomID,
		FromUserID:  fixtures.Member.FirebaseUID,
		ToUserID:    fixtures.Creator.FirebaseUID,
		Amount:      70,
		Notes:       "settle test balance",
	}))

	settledSummary, err := service.CalculateRoomspaceBalances(roomID)
	require.NoError(t, err)
	assert.InDelta(t, 0.0, settledSummary.UserBalances[fixtures.Creator.FirebaseUID], 0.01)
	assert.InDelta(t, 0.0, settledSummary.UserBalances[fixtures.Member.FirebaseUID], 0.01)

	cached, err := service.GetCachedBalance(roomID, fixtures.Member.FirebaseUID)
	require.NoError(t, err)
	assert.InDelta(t, 0.0, cached.Balance, 0.01)
}

func TestPaymentConfirmationService_DBWorkflow(t *testing.T) {
	t.Run("confirm creates settlement and settles balances", func(t *testing.T) {
		db := testutils.RequireTestDB(t)
		fixtures := testutils.SeedCore(t, db)
		service := NewPaymentConfirmationService(db, NewBalanceService(), NewPostgresService())

		payment, err := service.ConfirmPayment(fixtures.PaymentConfirmation.ID, fixtures.Creator.FirebaseUID)
		require.NoError(t, err)
		assert.Equal(t, models.PaymentStatusConfirmed, payment.Status)
		require.NotNil(t, payment.ConfirmedAt)

		var settlement models.Settlement
		require.NoError(t, db.Where("roomspace_id = ? AND from_user_id = ? AND to_user_id = ?",
			fixtures.Roomspace.ID.String(), fixtures.Member.FirebaseUID, fixtures.Creator.FirebaseUID).
			First(&settlement).Error)
		assert.InDelta(t, 70.0, settlement.Amount, 0.01)

		summary, err := NewBalanceService().CalculateRoomspaceBalances(fixtures.Roomspace.ID.String())
		require.NoError(t, err)
		assert.InDelta(t, 0.0, summary.UserBalances[fixtures.Creator.FirebaseUID], 0.01)
		assert.InDelta(t, 0.0, summary.UserBalances[fixtures.Member.FirebaseUID], 0.01)
	})

	t.Run("reject and unauthorized confirm are enforced", func(t *testing.T) {
		db := testutils.RequireTestDB(t)
		fixtures := testutils.SeedCore(t, db)
		service := NewPaymentConfirmationService(db, NewBalanceService(), NewPostgresService())

		_, err := service.ConfirmPayment(fixtures.PaymentConfirmation.ID, fixtures.Member.FirebaseUID)
		require.ErrorIs(t, err, models.ErrUnauthorized)

		payment, err := service.RejectPayment(fixtures.PaymentConfirmation.ID, fixtures.Creator.FirebaseUID, "wrong amount")
		require.NoError(t, err)
		assert.Equal(t, models.PaymentStatusRejected, payment.Status)
		assert.Equal(t, "wrong amount", payment.RejectionReason)

		_, err = service.RejectPayment(fixtures.PaymentConfirmation.ID, fixtures.Creator.FirebaseUID, "again")
		require.ErrorIs(t, err, models.ErrAlreadyRejected)
	})
}
