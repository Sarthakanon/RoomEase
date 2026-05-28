package testutils

import (
	"fmt"
	"net/url"
	"os"
	"regexp"
	"roomease/backend/config"
	"roomease/backend/models"
	"testing"
	"time"

	"github.com/google/uuid"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

const (
	DefaultTestDatabaseURL = "postgresql://postgres:roomease_dev_password@localhost:5432/roomease_test?sslmode=disable&search_path=public"
	testDBLockID           = 82700301
)

type Fixtures struct {
	Creator             models.User
	Member              models.User
	Outsider            models.User
	Roomspace           models.Roomspace
	OtherRoomspace      models.Roomspace
	EqualExpense        models.Expense
	ExactExpense        models.Expense
	DeletedExpense      models.Expense
	Notification        models.Notification
	JoinRequest         models.JoinRequest
	PaymentConfirmation models.PaymentConfirmation
}

func TestDatabaseURL() string {
	if value := os.Getenv("ROOM_EASE_TEST_DATABASE_URL"); value != "" {
		return value
	}
	u, err := url.Parse(DefaultTestDatabaseURL)
	if err != nil {
		return DefaultTestDatabaseURL
	}
	baseName := ""
	if len(u.Path) > 1 {
		baseName = u.Path[1:]
	}
	if baseName == "" {
		baseName = "roomease_test"
	}
	u.Path = fmt.Sprintf("/%s_%d", baseName, os.Getpid())
	return u.String()
}

func RequireTestDB(t *testing.T) *gorm.DB {
	t.Helper()

	if os.Getenv("ROOM_EASE_TEST_DB") != "true" {
		t.Skip("set ROOM_EASE_TEST_DB=true to run Postgres-backed tests")
	}

	dsn := TestDatabaseURL()
	ensureDatabaseExists(t, dsn)

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		t.Fatalf("connect test database: %v", err)
	}

	config.DB = db
	ResetDatabase(t, db)

	t.Cleanup(func() {
		sqlDB, err := db.DB()
		if err == nil {
			_ = sqlDB.Close()
		}
		if config.DB == db {
			config.DB = nil
		}
	})

	return db
}

func ResetDatabase(t *testing.T, db *gorm.DB) {
	t.Helper()

	tx := db.Begin()
	if tx.Error != nil {
		t.Fatalf("begin test database reset: %v", tx.Error)
	}
	defer tx.Rollback()

	if err := tx.Exec("SELECT pg_advisory_xact_lock(?)", testDBLockID).Error; err != nil {
		t.Fatalf("lock test database reset: %v", err)
	}
	if err := tx.Exec("DROP SCHEMA IF EXISTS public CASCADE").Error; err != nil {
		t.Fatalf("drop test schema: %v", err)
	}
	if err := tx.Exec("CREATE SCHEMA public").Error; err != nil {
		t.Fatalf("create test schema: %v", err)
	}
	if err := tx.Exec("SET search_path TO public").Error; err != nil {
		t.Fatalf("set test search path: %v", err)
	}
	if err := tx.Exec("CREATE EXTENSION IF NOT EXISTS pgcrypto").Error; err != nil {
		t.Fatalf("enable pgcrypto: %v", err)
	}
	if err := tx.AutoMigrate(
		&models.User{},
		&models.Notification{},
		&models.Roomspace{},
		&models.RoomspaceMember{},
		&models.JoinRequest{},
		&models.Expense{},
		&models.ExpenseSplit{},
		&models.PersonalExpense{},
		&models.PaymentNotification{},
		&models.AnalyticsCache{},
		&models.RecommendationFeedback{},
		&models.AnomalyAcknowledgment{},
		&models.MLModel{},
		&models.UserBalance{},
		&models.Settlement{},
		&models.PaymentConfirmation{},
		&models.RecurringExpenseTemplate{},
		&models.RecurringExpenseNotification{},
		&models.SubscriptionPayment{},
		&models.BalanceSettlement{},
		&models.ExpenseDeletionRequest{},
		&models.ExpenseDeletionApproval{},
		&models.ExpenseHistory{},
	); err != nil {
		t.Fatalf("auto migrate test database: %v", err)
	}
	if err := tx.Commit().Error; err != nil {
		t.Fatalf("commit test database reset: %v", err)
	}
}

func SeedCore(t *testing.T, db *gorm.DB) Fixtures {
	t.Helper()

	now := time.Now().UTC()
	creatorID := "test_creator"
	memberID := "test_member"
	outsideID := "test_outsider"

	fixtures := Fixtures{
		Creator: models.User{
			FirebaseUID:      creatorID,
			Email:            "creator@example.com",
			Name:             "Creator User",
			QRImageURL:       "https://example.com/creator-qr.png",
			SubscriptionPlan: "free",
		},
		Member: models.User{
			FirebaseUID:      memberID,
			Email:            "member@example.com",
			Name:             "Member User",
			QRImageURL:       "https://example.com/member-qr.png",
			SubscriptionPlan: "free",
		},
		Outsider: models.User{
			FirebaseUID:      outsideID,
			Email:            "outsider@example.com",
			Name:             "Outsider User",
			SubscriptionPlan: "free",
		},
	}

	mustCreate(t, db, &fixtures.Creator)
	mustCreate(t, db, &fixtures.Member)
	mustCreate(t, db, &fixtures.Outsider)

	fixtures.Roomspace = models.Roomspace{
		ID:         uuid.New(),
		Name:       "Test Roomspace",
		InviteCode: "TESTA001",
		CreatorID:  &creatorID,
		MaxMembers: 10,
	}
	fixtures.OtherRoomspace = models.Roomspace{
		ID:         uuid.New(),
		Name:       "Other Roomspace",
		InviteCode: "TESTB001",
		CreatorID:  &outsideID,
		MaxMembers: 10,
	}

	mustCreate(t, db, &fixtures.Roomspace)
	mustCreate(t, db, &fixtures.OtherRoomspace)

	mustCreate(t, db, &models.RoomspaceMember{RoomspaceID: fixtures.Roomspace.ID, UserID: creatorID, Role: models.RoleCreator, IsActive: true, JoinedAt: now})
	mustCreate(t, db, &models.RoomspaceMember{RoomspaceID: fixtures.Roomspace.ID, UserID: memberID, Role: models.RoleMember, IsActive: true, JoinedAt: now})
	mustCreate(t, db, &models.RoomspaceMember{RoomspaceID: fixtures.OtherRoomspace.ID, UserID: outsideID, Role: models.RoleCreator, IsActive: true, JoinedAt: now})

	roomID := fixtures.Roomspace.ID.String()
	otherRoomID := fixtures.OtherRoomspace.ID.String()

	fixtures.EqualExpense = models.Expense{
		RoomspaceID: roomID,
		Title:       "Shared Groceries",
		Amount:      300,
		Category:    "Groceries",
		PaidBy:      creatorID,
		CreatedBy:   creatorID,
		SplitType:   models.SplitTypeEqual,
		CreatedAt:   now.Add(-3 * time.Hour),
		Splits: []models.ExpenseSplit{
			{UserUID: creatorID, Amount: 150},
			{UserUID: memberID, Amount: 150},
		},
	}
	createExpenseWithSplits(t, db, &fixtures.EqualExpense)

	fixtures.ExactExpense = models.Expense{
		RoomspaceID: roomID,
		Title:       "Supplies",
		Amount:      120,
		Category:    "General",
		PaidBy:      memberID,
		CreatedBy:   memberID,
		SplitType:   models.SplitTypeExact,
		CreatedAt:   now.Add(-2 * time.Hour),
		Splits: []models.ExpenseSplit{
			{UserUID: creatorID, Amount: 80},
			{UserUID: memberID, Amount: 40},
		},
	}
	createExpenseWithSplits(t, db, &fixtures.ExactExpense)

	fixtures.DeletedExpense = models.Expense{
		RoomspaceID: roomID,
		Title:       "Deleted Expense",
		Amount:      999,
		Category:    "General",
		PaidBy:      creatorID,
		CreatedBy:   creatorID,
		SplitType:   models.SplitTypeEqual,
		CreatedAt:   now.Add(-1 * time.Hour),
		Splits: []models.ExpenseSplit{
			{UserUID: creatorID, Amount: 499.5},
			{UserUID: memberID, Amount: 499.5},
		},
	}
	createExpenseWithSplits(t, db, &fixtures.DeletedExpense)
	if err := db.Delete(&fixtures.DeletedExpense).Error; err != nil {
		t.Fatalf("soft delete fixture expense: %v", err)
	}

	otherExpense := models.Expense{
		RoomspaceID: otherRoomID,
		Title:       "Other Room Expense",
		Amount:      75,
		Category:    "Food",
		PaidBy:      outsideID,
		CreatedBy:   outsideID,
		SplitType:   models.SplitTypeEqual,
		Splits:      []models.ExpenseSplit{{UserUID: outsideID, Amount: 75}},
	}
	createExpenseWithSplits(t, db, &otherExpense)

	fixtures.Notification = models.Notification{
		RecipientUID: memberID,
		Type:         models.NotificationTypeExpenseAdded,
		Title:        "Expense added",
		Message:      "Shared Groceries was added",
		Data:         fmt.Sprintf(`{"roomspace_id":"%s"}`, roomID),
	}
	mustCreate(t, db, &fixtures.Notification)

	message := "Please let me in"
	fixtures.JoinRequest = models.JoinRequest{
		ID:          uuid.New(),
		RoomspaceID: fixtures.Roomspace.ID,
		RequesterID: outsideID,
		Status:      models.StatusPending,
		RequestedAt: now,
		ExpiresAt:   now.Add(7 * 24 * time.Hour),
		Message:     &message,
	}
	mustCreate(t, db, &fixtures.JoinRequest)

	fixtures.PaymentConfirmation = models.PaymentConfirmation{
		RoomspaceID: roomID,
		FromUserID:  memberID,
		ToUserID:    creatorID,
		Amount:      70,
		PaymentType: models.PaymentTypeFull,
		Status:      models.PaymentStatusPending,
		Notes:       "Fixture payment",
		PaymentDate: now,
	}
	mustCreate(t, db, &fixtures.PaymentConfirmation)

	return fixtures
}

func mustCreate(t *testing.T, db *gorm.DB, value interface{}) {
	t.Helper()
	if err := db.Create(value).Error; err != nil {
		t.Fatalf("create fixture %T: %v", value, err)
	}
}

func createExpenseWithSplits(t *testing.T, db *gorm.DB, expense *models.Expense) {
	t.Helper()
	splits := expense.Splits
	expense.Splits = nil
	mustCreate(t, db, expense)
	for i := range splits {
		splits[i].ExpenseID = expense.ID
		mustCreate(t, db, &splits[i])
	}
	expense.Splits = splits
}

func ensureDatabaseExists(t *testing.T, dsn string) {
	t.Helper()

	u, err := url.Parse(dsn)
	if err != nil {
		t.Fatalf("parse test database URL: %v", err)
	}
	dbName := databaseName(t, u)
	adminURL := *u
	adminURL.Path = "/postgres"

	adminDB, err := gorm.Open(postgres.Open(adminURL.String()), &gorm.Config{})
	if err != nil {
		t.Fatalf("connect postgres admin database: %v", err)
	}
	defer func() {
		sqlDB, err := adminDB.DB()
		if err == nil {
			_ = sqlDB.Close()
		}
	}()

	var exists bool
	if err := adminDB.Raw("SELECT EXISTS(SELECT 1 FROM pg_database WHERE datname = ?)", dbName).Scan(&exists).Error; err != nil {
		t.Fatalf("check test database existence: %v", err)
	}
	if exists {
		return
	}

	if err := adminDB.Exec("CREATE DATABASE " + quoteIdentifier(t, dbName)).Error; err != nil {
		if err := adminDB.Raw("SELECT EXISTS(SELECT 1 FROM pg_database WHERE datname = ?)", dbName).Scan(&exists).Error; err != nil {
			t.Fatalf("recheck test database existence: %v", err)
		}
		if !exists {
			t.Fatalf("create test database %s: %v", dbName, err)
		}
	}
}

func databaseName(t *testing.T, u *url.URL) string {
	t.Helper()
	dbName := ""
	if len(u.Path) > 1 {
		dbName = u.Path[1:]
	}
	if dbName == "" {
		t.Fatal("test database URL must include a database name")
	}
	return dbName
}

func quoteIdentifier(t *testing.T, value string) string {
	t.Helper()
	if !regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]*$`).MatchString(value) {
		t.Fatalf("unsafe database identifier: %s", value)
	}
	return `"` + value + `"`
}
