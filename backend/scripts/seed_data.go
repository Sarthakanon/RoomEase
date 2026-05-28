//go:build ignore

package main

import (
	"fmt"
	"log"
	"math/rand"
	"time"

	"roomease/backend/config"
	"roomease/backend/models"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// Seed data configuration
const (
	TotalUsers      = 100
	MinGroupSize    = 3
	MaxGroupSize    = 5
	ExpensesPerUser = 10 // Average expenses per user
)

var (
	// Sample data
	firstNames = []string{
		"John", "Jane", "Michael", "Emily", "David", "Sarah", "James", "Emma",
		"Robert", "Olivia", "William", "Ava", "Richard", "Isabella", "Joseph", "Sophia",
		"Thomas", "Mia", "Charles", "Charlotte", "Daniel", "Amelia", "Matthew", "Harper",
		"Anthony", "Evelyn", "Mark", "Abigail", "Donald", "Emily", "Steven", "Elizabeth",
		"Paul", "Sofia", "Andrew", "Avery", "Joshua", "Ella", "Kenneth", "Scarlett",
		"Kevin", "Grace", "Brian", "Chloe", "George", "Victoria", "Edward", "Madison",
		"Ronald", "Luna", "Timothy", "Aria", "Jason", "Layla", "Jeffrey", "Penelope",
		"Ryan", "Riley", "Jacob", "Zoey", "Gary", "Nora", "Nicholas", "Lily",
		"Eric", "Hannah", "Jonathan", "Lillian", "Stephen", "Addison", "Larry", "Eleanor",
		"Justin", "Natalie", "Scott", "Hazel", "Brandon", "Brooklyn", "Benjamin", "Savannah",
		"Samuel", "Audrey", "Raymond", "Claire", "Gregory", "Skylar", "Frank", "Lucy",
		"Alexander", "Paisley", "Patrick", "Everly", "Jack", "Anna", "Dennis", "Caroline",
	}

	lastNames = []string{
		"Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
		"Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson", "Thomas",
		"Taylor", "Moore", "Jackson", "Martin", "Lee", "Perez", "Thompson", "White",
		"Harris", "Sanchez", "Clark", "Ramirez", "Lewis", "Robinson", "Walker", "Young",
		"Allen", "King", "Wright", "Scott", "Torres", "Nguyen", "Hill", "Flores",
		"Green", "Adams", "Nelson", "Baker", "Hall", "Rivera", "Campbell", "Mitchell",
		"Carter", "Roberts", "Gomez", "Phillips", "Evans", "Turner", "Diaz", "Parker",
	}

	roomspaceNames = []string{
		"Sunset Apartment", "Downtown Loft", "Riverside House", "Mountain View Villa",
		"Ocean Breeze Condo", "City Center Flat", "Garden Terrace", "Lakeside Cottage",
		"Urban Studio", "Suburban Home", "Penthouse Suite", "Cozy Corner", "Modern Living",
		"Classic Residence", "Skyline Apartment", "Peaceful Haven", "Student Housing",
		"Professional Quarters", "Family Home", "Bachelor Pad", "Shared Space",
	}

	expenseCategories = []string{
		"Groceries", "Utilities", "Rent", "Food", "Transport", "Entertainment", "Other",
	}

	expenseTitles = map[string][]string{
		"Groceries": {
			"Weekly Groceries", "Supermarket Run", "Fresh Produce", "Bulk Shopping",
			"Organic Foods", "Snacks & Drinks", "Household Items", "Monthly Groceries",
		},
		"Utilities": {
			"Electricity Bill", "Water Bill", "Internet Bill", "Gas Bill",
			"Heating", "Cable TV", "Phone Bill", "Maintenance Fee",
		},
		"Rent": {
			"Monthly Rent", "Rent Payment", "House Rent", "Apartment Rent",
		},
		"Food": {
			"Pizza Night", "Restaurant Dinner", "Takeout", "Coffee Shop",
			"Lunch Together", "Breakfast", "Dinner Party", "Food Delivery",
		},
		"Transport": {
			"Uber Ride", "Gas Money", "Taxi Fare", "Public Transport",
			"Parking Fee", "Car Maintenance", "Fuel", "Bus Pass",
		},
		"Entertainment": {
			"Movie Tickets", "Concert", "Streaming Service", "Game Night",
			"Sports Event", "Museum Visit", "Theme Park", "Party Supplies",
		},
		"Other": {
			"Cleaning Supplies", "Repairs", "Furniture", "Decorations",
			"Pet Supplies", "Medical", "Gifts", "Miscellaneous",
		},
	}
)

func main() {
	log.Println("🌱 Starting data seeding...")

	// Load configuration
	cfg := config.LoadConfig()

	// Initialize PostgreSQL
	if err := config.InitPostgreSQL(cfg.PostgresDatabaseURL); err != nil {
		log.Fatalf("Failed to initialize PostgreSQL: %v", err)
	}
	defer config.ClosePostgreSQL()

	// Seed random number generator
	rand.Seed(time.Now().UnixNano())

	// Run seeding
	if err := seedData(config.DB); err != nil {
		log.Fatalf("Failed to seed data: %v", err)
	}

	log.Println("✅ Data seeding completed successfully!")
}

func seedData(db *gorm.DB) error {
	// Step 1: Create 100 users
	log.Println("📝 Creating 100 users...")
	users, err := createUsers(db, TotalUsers)
	if err != nil {
		return fmt.Errorf("failed to create users: %w", err)
	}
	log.Printf("✅ Created %d users\n", len(users))

	// Step 2: Create roomspaces (groups of 3-5 users)
	log.Println("🏠 Creating roomspaces...")
	roomspaces, userRoomspaces, err := createRoomspaces(db, users)
	if err != nil {
		return fmt.Errorf("failed to create roomspaces: %w", err)
	}
	log.Printf("✅ Created %d roomspaces\n", len(roomspaces))

	// Step 3: Create expenses for each roomspace
	log.Println("💰 Creating expenses...")
	totalExpenses, err := createExpenses(db, roomspaces, userRoomspaces)
	if err != nil {
		return fmt.Errorf("failed to create expenses: %w", err)
	}
	log.Printf("✅ Created %d expenses\n", totalExpenses)

	// Step 4: Create personal expenses
	log.Println("💳 Creating personal expenses...")
	personalExpenses, err := createPersonalExpenses(db, users)
	if err != nil {
		return fmt.Errorf("failed to create personal expenses: %w", err)
	}
	log.Printf("✅ Created %d personal expenses\n", personalExpenses)

	return nil
}

func createUsers(db *gorm.DB, count int) ([]*models.User, error) {
	users := make([]*models.User, 0, count)

	for i := 0; i < count; i++ {
		firstName := firstNames[rand.Intn(len(firstNames))]
		lastName := lastNames[rand.Intn(len(lastNames))]

		user := &models.User{
			FirebaseUID: fmt.Sprintf("user_%d_%s", i+1, uuid.New().String()[:8]),
			Email: fmt.Sprintf("%s.%s%d@roomease.test",
				toLowerCase(firstName), toLowerCase(lastName), i+1),
			Name:             fmt.Sprintf("%s %s", firstName, lastName),
			Phone:            fmt.Sprintf("+1%010d", rand.Intn(10000000000)),
			SubscriptionPlan: getRandomSubscriptionPlan(),
			CreatedAt:        time.Now().Add(-time.Duration(rand.Intn(365)) * 24 * time.Hour),
		}

		// Set subscription expiry for pro users
		if user.SubscriptionPlan == "pro" {
			expiry := time.Now().Add(time.Duration(rand.Intn(365)) * 24 * time.Hour)
			user.SubscriptionExpiry = &expiry
		}

		if err := db.Create(user).Error; err != nil {
			return nil, fmt.Errorf("failed to create user %d: %w", i+1, err)
		}

		users = append(users, user)
	}

	return users, nil
}

func createRoomspaces(db *gorm.DB, users []*models.User) ([]*models.Roomspace, map[string][]string, error) {
	roomspaces := make([]*models.Roomspace, 0)
	userRoomspaces := make(map[string][]string) // userUID -> []roomspaceID
	usedUsers := make(map[string]bool)

	availableUsers := make([]*models.User, len(users))
	copy(availableUsers, users)

	roomspaceIndex := 0

	for len(availableUsers) >= MinGroupSize {
		// Determine group size
		maxPossible := MaxGroupSize
		if len(availableUsers) < maxPossible {
			maxPossible = len(availableUsers)
		}
		groupSize := MinGroupSize + rand.Intn(maxPossible-MinGroupSize+1)

		// Select users for this roomspace
		groupUsers := make([]*models.User, groupSize)
		for i := 0; i < groupSize; i++ {
			idx := rand.Intn(len(availableUsers))
			groupUsers[i] = availableUsers[idx]
			// Remove from available users
			availableUsers = append(availableUsers[:idx], availableUsers[idx+1:]...)
		}

		// Create roomspace
		creator := groupUsers[0]
		roomspaceName := roomspaceNames[roomspaceIndex%len(roomspaceNames)]
		if roomspaceIndex >= len(roomspaceNames) {
			roomspaceName = fmt.Sprintf("%s %d", roomspaceName, roomspaceIndex/len(roomspaceNames)+1)
		}

		description := fmt.Sprintf("A shared living space for %d roommates", groupSize)
		roomspace := &models.Roomspace{
			ID:          uuid.New(),
			Name:        roomspaceName,
			Description: &description,
			InviteCode:  generateInviteCode(),
			CreatorID:   &creator.FirebaseUID,
			MaxMembers:  groupSize + 2, // Allow some buffer
			CreatedAt:   time.Now().Add(-time.Duration(rand.Intn(180)) * 24 * time.Hour),
		}

		if err := db.Create(roomspace).Error; err != nil {
			return nil, nil, fmt.Errorf("failed to create roomspace: %w", err)
		}

		// Add members
		for i, user := range groupUsers {
			role := models.RoleMember
			if i == 0 {
				role = models.RoleCreator
			}

			member := &models.RoomspaceMember{
				RoomspaceID: roomspace.ID,
				UserID:      user.FirebaseUID,
				Role:        role,
				IsActive:    true,
				JoinedAt:    roomspace.CreatedAt.Add(time.Duration(i) * time.Hour),
			}

			if err := db.Create(member).Error; err != nil {
				return nil, nil, fmt.Errorf("failed to create member: %w", err)
			}

			// Track user-roomspace mapping
			userRoomspaces[user.FirebaseUID] = append(userRoomspaces[user.FirebaseUID], roomspace.ID.String())
			usedUsers[user.FirebaseUID] = true
		}

		roomspaces = append(roomspaces, roomspace)
		roomspaceIndex++
	}

	return roomspaces, userRoomspaces, nil
}

func createExpenses(db *gorm.DB, roomspaces []*models.Roomspace, userRoomspaces map[string][]string) (int, error) {
	totalExpenses := 0

	for _, roomspace := range roomspaces {
		// Get members of this roomspace
		var members []models.RoomspaceMember
		if err := db.Where("roomspace_id = ? AND is_active = ?", roomspace.ID, true).
			Find(&members).Error; err != nil {
			return 0, fmt.Errorf("failed to get members: %w", err)
		}

		if len(members) == 0 {
			continue
		}

		// Create 15-30 expenses per roomspace
		numExpenses := 15 + rand.Intn(16)

		for i := 0; i < numExpenses; i++ {
			// Random category
			category := expenseCategories[rand.Intn(len(expenseCategories))]

			// Random title from category
			titles := expenseTitles[category]
			title := titles[rand.Intn(len(titles))]

			// Random amount based on category
			amount := getRandomAmount(category)

			// Random payer
			payer := members[rand.Intn(len(members))]

			// Random split type
			splitType := getRandomSplitType()

			// Create expense
			expense := &models.Expense{
				RoomspaceID: roomspace.ID.String(),
				Title:       title,
				Description: fmt.Sprintf("%s for %s", title, roomspace.Name),
				Amount:      amount,
				Category:    category,
				PaidBy:      payer.UserID,
				SplitType:   splitType,
				CreatedAt:   time.Now().Add(-time.Duration(rand.Intn(90)) * 24 * time.Hour),
			}

			if err := db.Create(expense).Error; err != nil {
				return 0, fmt.Errorf("failed to create expense: %w", err)
			}

			// Create splits
			if err := createExpenseSplits(db, expense, members, splitType); err != nil {
				return 0, fmt.Errorf("failed to create splits: %w", err)
			}

			totalExpenses++
		}
	}

	return totalExpenses, nil
}

func createExpenseSplits(db *gorm.DB, expense *models.Expense, members []models.RoomspaceMember, splitType models.ExpenseSplitType) error {
	numMembers := len(members)

	switch splitType {
	case models.SplitTypeEqual:
		splitAmount := expense.Amount / float64(numMembers)
		for _, member := range members {
			split := &models.ExpenseSplit{
				ExpenseID:  expense.ID,
				UserUID:    member.UserID,
				Amount:     splitAmount,
				Percentage: 100.0 / float64(numMembers),
			}
			if err := db.Create(split).Error; err != nil {
				return err
			}
		}

	case models.SplitTypePercentage:
		// Generate random percentages that sum to 100
		percentages := generateRandomPercentages(numMembers)
		for i, member := range members {
			splitAmount := expense.Amount * percentages[i] / 100.0
			split := &models.ExpenseSplit{
				ExpenseID:  expense.ID,
				UserUID:    member.UserID,
				Amount:     splitAmount,
				Percentage: percentages[i],
			}
			if err := db.Create(split).Error; err != nil {
				return err
			}
		}

	case models.SplitTypeExact:
		// Generate random amounts that sum to total
		amounts := generateRandomAmounts(expense.Amount, numMembers)
		for i, member := range members {
			split := &models.ExpenseSplit{
				ExpenseID:  expense.ID,
				UserUID:    member.UserID,
				Amount:     amounts[i],
				Percentage: (amounts[i] / expense.Amount) * 100.0,
			}
			if err := db.Create(split).Error; err != nil {
				return err
			}
		}
	}

	return nil
}

func createPersonalExpenses(db *gorm.DB, users []*models.User) (int, error) {
	totalExpenses := 0

	for _, user := range users {
		// Create 3-8 personal expenses per user
		numExpenses := 3 + rand.Intn(6)

		for i := 0; i < numExpenses; i++ {
			category := expenseCategories[rand.Intn(len(expenseCategories))]
			titles := expenseTitles[category]
			title := titles[rand.Intn(len(titles))]
			amount := getRandomAmount(category) / 2 // Personal expenses are typically smaller

			expense := &models.PersonalExpense{
				UserUID:     user.FirebaseUID,
				Title:       title,
				Description: fmt.Sprintf("Personal %s", title),
				Amount:      amount,
				Category:    category,
				CreatedAt:   time.Now().Add(-time.Duration(rand.Intn(90)) * 24 * time.Hour),
			}

			if err := db.Create(expense).Error; err != nil {
				return 0, fmt.Errorf("failed to create personal expense: %w", err)
			}

			totalExpenses++
		}
	}

	return totalExpenses, nil
}

// Helper functions

func toLowerCase(s string) string {
	return string([]rune(s)[0]+32) + s[1:]
}

func generateInviteCode() string {
	const charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	code := make([]byte, 8)
	for i := range code {
		code[i] = charset[rand.Intn(len(charset))]
	}
	return string(code)
}

func getRandomSubscriptionPlan() string {
	// 80% free, 20% pro
	if rand.Float64() < 0.8 {
		return "free"
	}
	return "pro"
}

func getRandomSplitType() models.ExpenseSplitType {
	// 60% equal, 25% percentage, 15% exact
	r := rand.Float64()
	if r < 0.6 {
		return models.SplitTypeEqual
	} else if r < 0.85 {
		return models.SplitTypePercentage
	}
	return models.SplitTypeExact
}

func getRandomAmount(category string) float64 {
	switch category {
	case "Rent":
		return float64(500 + rand.Intn(1500)) // $500-$2000
	case "Utilities":
		return float64(50 + rand.Intn(200)) // $50-$250
	case "Groceries":
		return float64(30 + rand.Intn(170)) // $30-$200
	case "Food":
		return float64(15 + rand.Intn(85)) // $15-$100
	case "Transport":
		return float64(10 + rand.Intn(90)) // $10-$100
	case "Entertainment":
		return float64(20 + rand.Intn(130)) // $20-$150
	default:
		return float64(10 + rand.Intn(90)) // $10-$100
	}
}

func generateRandomPercentages(count int) []float64 {
	percentages := make([]float64, count)
	remaining := 100.0

	for i := 0; i < count-1; i++ {
		// Generate random percentage between 10% and remaining-10*(count-i-1)
		maxPercent := remaining - 10.0*float64(count-i-1)
		if maxPercent < 10.0 {
			maxPercent = 10.0
		}
		percentages[i] = 10.0 + rand.Float64()*(maxPercent-10.0)
		remaining -= percentages[i]
	}
	percentages[count-1] = remaining

	return percentages
}

func generateRandomAmounts(total float64, count int) []float64 {
	amounts := make([]float64, count)
	remaining := total

	for i := 0; i < count-1; i++ {
		// Generate random amount between 10% and remaining-10*(count-i-1)
		minAmount := total * 0.1
		maxAmount := remaining - minAmount*float64(count-i-1)
		if maxAmount < minAmount {
			maxAmount = minAmount
		}
		amounts[i] = minAmount + rand.Float64()*(maxAmount-minAmount)
		remaining -= amounts[i]
	}
	amounts[count-1] = remaining

	return amounts
}
