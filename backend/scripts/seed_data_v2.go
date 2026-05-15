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

// Predefined test users with email/password credentials
type TestUser struct {
	Email     string
	Password  string
	Name      string
	GroupName string
}

var testUsers = []TestUser{
	// Group 1: "Sunset Apartment" (4 people)
	{Email: "john.smith@roomease.test", Password: "Test@123", Name: "John Smith", GroupName: "Sunset Apartment"},
	{Email: "jane.doe@roomease.test", Password: "Test@123", Name: "Jane Doe", GroupName: "Sunset Apartment"},
	{Email: "mike.wilson@roomease.test", Password: "Test@123", Name: "Mike Wilson", GroupName: "Sunset Apartment"},
	{Email: "sarah.johnson@roomease.test", Password: "Test@123", Name: "Sarah Johnson", GroupName: "Sunset Apartment"},

	// Group 2: "Downtown Loft" (4 people)
	{Email: "david.brown@roomease.test", Password: "Test@123", Name: "David Brown", GroupName: "Downtown Loft"},
	{Email: "emily.davis@roomease.test", Password: "Test@123", Name: "Emily Davis", GroupName: "Downtown Loft"},
	{Email: "chris.miller@roomease.test", Password: "Test@123", Name: "Chris Miller", GroupName: "Downtown Loft"},
	{Email: "lisa.garcia@roomease.test", Password: "Test@123", Name: "Lisa Garcia", GroupName: "Downtown Loft"},

	// Group 3: "Riverside House" (3 people)
	{Email: "robert.martinez@roomease.test", Password: "Test@123", Name: "Robert Martinez", GroupName: "Riverside House"},
	{Email: "amanda.rodriguez@roomease.test", Password: "Test@123", Name: "Amanda Rodriguez", GroupName: "Riverside House"},
	{Email: "kevin.lopez@roomease.test", Password: "Test@123", Name: "Kevin Lopez", GroupName: "Riverside House"},

	// Group 4: "Mountain View Villa" (3 people)
	{Email: "jessica.hernandez@roomease.test", Password: "Test@123", Name: "Jessica Hernandez", GroupName: "Mountain View Villa"},
	{Email: "daniel.gonzalez@roomease.test", Password: "Test@123", Name: "Daniel Gonzalez", GroupName: "Mountain View Villa"},
	{Email: "michelle.wilson@roomease.test", Password: "Test@123", Name: "Michelle Wilson", GroupName: "Mountain View Villa"},

	// Group 5: "Ocean Breeze Condo" (2 people)
	{Email: "thomas.anderson@roomease.test", Password: "Test@123", Name: "Thomas Anderson", GroupName: "Ocean Breeze Condo"},
	{Email: "jennifer.taylor@roomease.test", Password: "Test@123", Name: "Jennifer Taylor", GroupName: "Ocean Breeze Condo"},

	// Group 6: "City Center Flat" (2 people)
	{Email: "james.moore@roomease.test", Password: "Test@123", Name: "James Moore", GroupName: "City Center Flat"},
	{Email: "patricia.jackson@roomease.test", Password: "Test@123", Name: "Patricia Jackson", GroupName: "City Center Flat"},
}

var expenseCategories = []string{
	"Groceries", "Utilities", "Rent", "Food", "Transport", "Entertainment", "Other",
}

var expenseTitles = map[string][]string{
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

func main() {
	log.Println("🌱 Starting RoomEase data seeding v2...")

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
	log.Println("")
	log.Println("📧 TEST USER CREDENTIALS:")
	log.Println("=" + string(make([]byte, 60)))
	printCredentials()
}

func seedData(db *gorm.DB) error {
	// Step 1: Create test users
	log.Println("📝 Creating test users...")
	users, err := createTestUsers(db)
	if err != nil {
		return fmt.Errorf("failed to create users: %w", err)
	}
	log.Printf("✅ Created %d users\n", len(users))

	// Step 2: Create roomspaces with specific groups
	log.Println("🏠 Creating roomspaces...")
	roomspaces, userRoomspaces, err := createRoomspacesFromGroups(db, users)
	if err != nil {
		return fmt.Errorf("failed to create roomspaces: %w", err)
	}
	log.Printf("✅ Created %d roomspaces\n", len(roomspaces))

	// Step 3: Create expenses for each roomspace (each user pays some expenses)
	log.Println("💰 Creating expenses...")
	totalExpenses, err := createExpensesForRoomspaces(db, roomspaces, userRoomspaces)
	if err != nil {
		return fmt.Errorf("failed to create expenses: %w", err)
	}
	log.Printf("✅ Created %d expenses\n", totalExpenses)

	// Step 4: Create personal expenses for each user
	log.Println("💳 Creating personal expenses...")
	personalExpenses, err := createPersonalExpensesForUsers(db, users)
	if err != nil {
		return fmt.Errorf("failed to create personal expenses: %w", err)
	}
	log.Printf("✅ Created %d personal expenses\n", personalExpenses)

	return nil
}

func createTestUsers(db *gorm.DB) (map[string]*models.User, error) {
	users := make(map[string]*models.User)

	for i, testUser := range testUsers {
		// Generate Firebase UID (in real app, this comes from Firebase)
		firebaseUID := fmt.Sprintf("test_user_%d_%s", i+1, uuid.New().String()[:8])

		// Set subscription expiry for PRO users (all users are PRO)
		expiry := time.Now().Add(365 * 24 * time.Hour) // 1 year from now

		user := &models.User{
			FirebaseUID:        firebaseUID,
			Email:              testUser.Email,
			Name:               testUser.Name,
			Phone:              fmt.Sprintf("+1%010d", 2000000000+i),
			SubscriptionPlan:   "pro", // All users on PRO plan
			SubscriptionExpiry: &expiry,
			CreatedAt:          time.Now().Add(-time.Duration(rand.Intn(90)) * 24 * time.Hour),
		}

		if err := db.Create(user).Error; err != nil {
			return nil, fmt.Errorf("failed to create user %s: %w", testUser.Email, err)
		}

		users[testUser.Email] = user
	}

	return users, nil
}

func createRoomspacesFromGroups(db *gorm.DB, users map[string]*models.User) ([]*models.Roomspace, map[string][]string, error) {
	roomspaces := make([]*models.Roomspace, 0)
	userRoomspaces := make(map[string][]string) // userUID -> []roomspaceID

	// Group users by GroupName
	groups := make(map[string][]string) // groupName -> []email
	for _, testUser := range testUsers {
		groups[testUser.GroupName] = append(groups[testUser.GroupName], testUser.Email)
	}

	// Create a roomspace for each group
	for groupName, emails := range groups {
		// Get users for this group
		groupUsers := make([]*models.User, 0)
		for _, email := range emails {
			if user, exists := users[email]; exists {
				groupUsers = append(groupUsers, user)
			}
		}

		if len(groupUsers) == 0 {
			continue
		}

		// First user is the creator
		creator := groupUsers[0]
		description := fmt.Sprintf("A shared living space for %d roommates", len(groupUsers))

		roomspace := &models.Roomspace{
			ID:          uuid.New(),
			Name:        groupName,
			Description: &description,
			InviteCode:  generateInviteCode(),
			CreatorID:   &creator.FirebaseUID,
			MaxMembers:  len(groupUsers) + 2, // Allow some buffer
			CreatedAt:   time.Now().Add(-time.Duration(rand.Intn(180)) * 24 * time.Hour),
		}

		if err := db.Create(roomspace).Error; err != nil {
			return nil, nil, fmt.Errorf("failed to create roomspace %s: %w", groupName, err)
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
		}

		roomspaces = append(roomspaces, roomspace)
	}

	return roomspaces, userRoomspaces, nil
}

func createExpensesForRoomspaces(db *gorm.DB, roomspaces []*models.Roomspace, userRoomspaces map[string][]string) (int, error) {
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

		// Create 20-30 expenses per roomspace
		numExpenses := 20 + rand.Intn(11)

		// Ensure each member pays at least some expenses
		expensesPerMember := numExpenses / len(members)
		extraExpenses := numExpenses % len(members)

		expenseIndex := 0
		for memberIdx, member := range members {
			// Number of expenses this member will pay
			memberExpenseCount := expensesPerMember
			if memberIdx < extraExpenses {
				memberExpenseCount++
			}

			for i := 0; i < memberExpenseCount; i++ {
				// Random category
				category := expenseCategories[rand.Intn(len(expenseCategories))]

				// Random title from category
				titles := expenseTitles[category]
				title := titles[rand.Intn(len(titles))]

				// Random amount based on category
				amount := getRandomAmount(category)

				// Random split type
				splitType := getRandomSplitType()

				// Create expense (paid by this member)
				expense := &models.Expense{
					RoomspaceID: roomspace.ID.String(),
					Title:       title,
					Description: fmt.Sprintf("%s for %s", title, roomspace.Name),
					Amount:      amount,
					Category:    category,
					PaidBy:      member.UserID,
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
				expenseIndex++
			}
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

func createPersonalExpensesForUsers(db *gorm.DB, users map[string]*models.User) (int, error) {
	totalExpenses := 0

	for _, user := range users {
		// Create 5-10 personal expenses per user
		numExpenses := 5 + rand.Intn(6)

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

func generateInviteCode() string {
	const charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	code := make([]byte, 8)
	for i := range code {
		code[i] = charset[rand.Intn(len(charset))]
	}
	return string(code)
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

func printCredentials() {
	currentGroup := ""
	for _, user := range testUsers {
		if user.GroupName != currentGroup {
			if currentGroup != "" {
				fmt.Println("")
			}
			fmt.Printf("📍 %s:\n", user.GroupName)
			fmt.Println("   " + string(make([]byte, 50)))
			currentGroup = user.GroupName
		}
		fmt.Printf("   Email:    %s\n", user.Email)
		fmt.Printf("   Password: %s\n", user.Password)
		fmt.Printf("   Name:     %s\n", user.Name)
		fmt.Println("")
	}
	fmt.Println("=" + string(make([]byte, 60)))
	fmt.Println("")
	fmt.Println("⚠️  NOTE: These are test accounts with Firebase UIDs.")
	fmt.Println("   For email/password login, you need to:")
	fmt.Println("   1. Create these users in Firebase Authentication")
	fmt.Println("   2. Or use Google Sign-In with these email addresses")
	fmt.Println("")
}
