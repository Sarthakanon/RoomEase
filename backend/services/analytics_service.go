package services

import (
	"fmt"
	"math"
	"roomease/backend/config"
	"roomease/backend/models"
	"time"
)

// AnalyticsService handles analytics operations
type AnalyticsService struct {
	dbService *PostgresService
}

// NewAnalyticsService creates a new analytics service
func NewAnalyticsService(dbService *PostgresService) *AnalyticsService {
	return &AnalyticsService{
		dbService: dbService,
	}
}

// CategorySpend represents spending in a category
type CategorySpend struct {
	Category   string  `json:"category"`
	Amount     float64 `json:"amount"`
	Percentage float64 `json:"percentage"`
	Count      int     `json:"count"`
}

// AnalyticsSummary represents spending summary
type AnalyticsSummary struct {
	TotalSpent         float64         `json:"total_spent"`
	PredictedNextMonth float64         `json:"predicted_next_month"`
	SavingsPotential   float64         `json:"savings_potential"`
	TopCategories      []CategorySpend `json:"top_categories"`
	SpendingTrend      string          `json:"spending_trend"` // "increasing", "decreasing", "stable"
}

// GetSpendingSummary calculates spending summary for a user
func (s *AnalyticsService) GetSpendingSummary(userUID string, roomspaceID *string, startDate, endDate time.Time) (*AnalyticsSummary, error) {
	// Get expenses for the period
	expenses, err := s.getExpensesForPeriod(userUID, roomspaceID, startDate, endDate)
	if err != nil {
		return nil, fmt.Errorf("failed to get expenses: %v", err)
	}

	// Calculate total spent
	totalSpent := 0.0
	categoryTotals := make(map[string]*CategorySpend)

	for _, expense := range expenses {
		// For shared expenses, only count the user's split
		userAmount := s.getUserAmountFromExpense(&expense, userUID)
		totalSpent += userAmount

		// Aggregate by category
		if _, exists := categoryTotals[expense.Category]; !exists {
			categoryTotals[expense.Category] = &CategorySpend{
				Category: expense.Category,
				Amount:   0,
				Count:    0,
			}
		}
		categoryTotals[expense.Category].Amount += userAmount
		categoryTotals[expense.Category].Count++
	}

	// Calculate percentages
	topCategories := s.calculateCategoryPercentages(categoryTotals, totalSpent)

	// Calculate spending trend
	trend := s.calculateSpendingTrend(userUID, roomspaceID, endDate)

	summary := &AnalyticsSummary{
		TotalSpent:         totalSpent,
		PredictedNextMonth: 0, // Will be set by prediction service
		SavingsPotential:   0, // Will be set by recommendation engine
		TopCategories:      topCategories,
		SpendingTrend:      trend,
	}

	return summary, nil
}

// GetCategoryBreakdown returns category-wise spending breakdown
func (s *AnalyticsService) GetCategoryBreakdown(userUID string, roomspaceID *string, startDate, endDate time.Time) ([]CategorySpend, error) {
	// Get expenses for the period
	expenses, err := s.getExpensesForPeriod(userUID, roomspaceID, startDate, endDate)
	if err != nil {
		return nil, fmt.Errorf("failed to get expenses: %v", err)
	}

	// Calculate total and category totals
	totalSpent := 0.0
	categoryTotals := make(map[string]*CategorySpend)

	for _, expense := range expenses {
		userAmount := s.getUserAmountFromExpense(&expense, userUID)
		totalSpent += userAmount

		if _, exists := categoryTotals[expense.Category]; !exists {
			categoryTotals[expense.Category] = &CategorySpend{
				Category: expense.Category,
				Amount:   0,
				Count:    0,
			}
		}
		categoryTotals[expense.Category].Amount += userAmount
		categoryTotals[expense.Category].Count++
	}

	// Calculate percentages and return sorted list
	return s.calculateCategoryPercentages(categoryTotals, totalSpent), nil
}

// Helper functions

// getExpensesForPeriod retrieves expenses for a user within a date range
func (s *AnalyticsService) getExpensesForPeriod(userUID string, roomspaceID *string, startDate, endDate time.Time) ([]models.Expense, error) {
	var expenses []models.Expense

	query := config.DB.Where("created_at >= ? AND created_at <= ?", startDate, endDate)

	if roomspaceID != nil {
		// Get roomspace expenses
		query = query.Where("roomspace_id = ?", *roomspaceID)
	} else {
		// Get all expenses where user is involved (paid or has a split)
		query = query.Where("paid_by = ? OR id IN (SELECT expense_id FROM expense_splits WHERE user_uid = ?)", userUID, userUID)
	}

	query = query.Preload("Splits").Order("created_at DESC")

	if err := query.Find(&expenses).Error; err != nil {
		return nil, err
	}

	return expenses, nil
}

// getUserAmountFromExpense calculates the amount a user owes/paid for an expense
func (s *AnalyticsService) getUserAmountFromExpense(expense *models.Expense, userUID string) float64 {
	// Find the user's split
	for _, split := range expense.Splits {
		if split.UserUID == userUID {
			return split.Amount
		}
	}
	return 0.0
}

// calculateCategoryPercentages calculates percentages and sorts categories by amount
func (s *AnalyticsService) calculateCategoryPercentages(categoryTotals map[string]*CategorySpend, totalSpent float64) []CategorySpend {
	var categories []CategorySpend

	for _, cat := range categoryTotals {
		if totalSpent > 0 {
			cat.Percentage = (cat.Amount / totalSpent) * 100.0
		} else {
			cat.Percentage = 0
		}
		categories = append(categories, *cat)
	}

	// Sort by amount (descending)
	for i := 0; i < len(categories); i++ {
		for j := i + 1; j < len(categories); j++ {
			if categories[j].Amount > categories[i].Amount {
				categories[i], categories[j] = categories[j], categories[i]
			}
		}
	}

	return categories
}

// calculateSpendingTrend determines if spending is increasing, decreasing, or stable
func (s *AnalyticsService) calculateSpendingTrend(userUID string, roomspaceID *string, currentDate time.Time) string {
	// Compare current month to previous month
	currentMonthStart := time.Date(currentDate.Year(), currentDate.Month(), 1, 0, 0, 0, 0, currentDate.Location())
	currentMonthEnd := currentDate

	prevMonthEnd := currentMonthStart.Add(-time.Second)
	prevMonthStart := time.Date(prevMonthEnd.Year(), prevMonthEnd.Month(), 1, 0, 0, 0, 0, prevMonthEnd.Location())

	// Get current month expenses
	currentExpenses, err := s.getExpensesForPeriod(userUID, roomspaceID, currentMonthStart, currentMonthEnd)
	if err != nil {
		return "stable"
	}

	// Get previous month expenses
	prevExpenses, err := s.getExpensesForPeriod(userUID, roomspaceID, prevMonthStart, prevMonthEnd)
	if err != nil {
		return "stable"
	}

	// Calculate totals
	currentTotal := 0.0
	for _, exp := range currentExpenses {
		currentTotal += s.getUserAmountFromExpense(&exp, userUID)
	}

	prevTotal := 0.0
	for _, exp := range prevExpenses {
		prevTotal += s.getUserAmountFromExpense(&exp, userUID)
	}

	// Determine trend (>10% change is significant)
	if prevTotal == 0 {
		return "stable"
	}

	changePercent := ((currentTotal - prevTotal) / prevTotal) * 100.0

	if changePercent > 10 {
		return "increasing"
	} else if changePercent < -10 {
		return "decreasing"
	}

	return "stable"
}

// GetExpenseHistory returns expense data points for trend charts
func (s *AnalyticsService) GetExpenseHistory(userUID string, roomspaceID *string, startDate, endDate time.Time, groupBy string) ([]map[string]interface{}, error) {
	expenses, err := s.getExpensesForPeriod(userUID, roomspaceID, startDate, endDate)
	if err != nil {
		return nil, err
	}

	// Group expenses by time period
	dataPoints := make(map[string]float64)

	for _, expense := range expenses {
		userAmount := s.getUserAmountFromExpense(&expense, userUID)

		var key string
		switch groupBy {
		case "day":
			key = expense.CreatedAt.Format("2006-01-02")
		case "week":
			year, week := expense.CreatedAt.ISOWeek()
			key = fmt.Sprintf("%d-W%02d", year, week)
		case "month":
			key = expense.CreatedAt.Format("2006-01")
		default:
			key = expense.CreatedAt.Format("2006-01-02")
		}

		dataPoints[key] += userAmount
	}

	// Convert to array format
	var result []map[string]interface{}
	for date, amount := range dataPoints {
		result = append(result, map[string]interface{}{
			"date":   date,
			"amount": math.Round(amount*100) / 100, // Round to 2 decimal places
		})
	}

	return result, nil
}

// SpendingPrediction represents a prediction for future spending
type SpendingPrediction struct {
	Category        string  `json:"category"`
	PredictedAmount float64 `json:"predicted_amount"`
	ConfidenceLow   float64 `json:"confidence_low"`
	ConfidenceHigh  float64 `json:"confidence_high"`
	HistoricalAvg   float64 `json:"historical_avg"`
}

// PredictionResult contains predictions and metadata
type PredictionResult struct {
	Predictions      []SpendingPrediction `json:"predictions"`
	InsufficientData bool                 `json:"insufficient_data"`
	DataDays         int                  `json:"data_days"`
	Message          string               `json:"message,omitempty"`
}

// GetSpendingPredictions generates spending predictions for the next month
// NOTE: This now returns simple historical averages. For ML-based predictions,
// use the Analytics_Model Python service
func (s *AnalyticsService) GetSpendingPredictions(userUID string, roomspaceID *string) (*PredictionResult, error) {
	// Check if user has at least 30 days of data
	now := time.Now()
	thirtyDaysAgo := now.AddDate(0, 0, -30)

	expenses, err := s.getExpensesForPeriod(userUID, roomspaceID, thirtyDaysAgo, now)
	if err != nil {
		return nil, fmt.Errorf("failed to get expenses: %v", err)
	}

	// Calculate actual days of data
	var oldestDate time.Time
	if len(expenses) > 0 {
		oldestDate = expenses[len(expenses)-1].CreatedAt
		for _, exp := range expenses {
			if exp.CreatedAt.Before(oldestDate) {
				oldestDate = exp.CreatedAt
			}
		}
	}

	dataDays := int(now.Sub(oldestDate).Hours() / 24)

	// If less than 30 days of data, return insufficient data message
	if len(expenses) == 0 || dataDays < 30 {
		return &PredictionResult{
			Predictions:      []SpendingPrediction{},
			InsufficientData: true,
			DataDays:         dataDays,
			Message:          fmt.Sprintf("Need at least 30 days of expense history. Currently have %d days.", dataDays),
		}, nil
	}

	// Simple prediction based on historical average (no ML)
	categoryData := make(map[string][]float64)

	for _, expense := range expenses {
		userAmount := s.getUserAmountFromExpense(&expense, userUID)
		categoryData[expense.Category] = append(categoryData[expense.Category], userAmount)
	}

	var predictions []SpendingPrediction

	for category, amounts := range categoryData {
		// Calculate historical average
		sum := 0.0
		for _, amount := range amounts {
			sum += amount
		}
		avg := sum / float64(len(amounts))

		// Simple prediction: average * expected transactions
		daysInPeriod := float64(dataDays)
		transactionsPerDay := float64(len(amounts)) / daysInPeriod
		expectedTransactions := transactionsPerDay * 30.0

		predictedAmount := avg * expectedTransactions

		predictions = append(predictions, SpendingPrediction{
			Category:        category,
			PredictedAmount: math.Round(predictedAmount*100) / 100,
			ConfidenceLow:   math.Round(predictedAmount*0.8*100) / 100,
			ConfidenceHigh:  math.Round(predictedAmount*1.2*100) / 100,
			HistoricalAvg:   math.Round(avg*100) / 100,
		})
	}

	// Sort predictions by predicted amount (descending)
	for i := 0; i < len(predictions); i++ {
		for j := i + 1; j < len(predictions); j++ {
			if predictions[j].PredictedAmount > predictions[i].PredictedAmount {
				predictions[i], predictions[j] = predictions[j], predictions[i]
			}
		}
	}

	return &PredictionResult{
		Predictions:      predictions,
		InsufficientData: false,
		DataDays:         dataDays,
	}, nil
}

// Recommendation represents a budget recommendation
type Recommendation struct {
	ID               string  `json:"id"`
	Type             string  `json:"type"` // budget_limit, reduce_spending, savings_opportunity
	Category         string  `json:"category"`
	CurrentSpending  float64 `json:"current_spending"`
	SuggestedLimit   float64 `json:"suggested_limit"`
	PotentialSavings float64 `json:"potential_savings"`
	Description      string  `json:"description"`
	Priority         int     `json:"priority"` // 1=high, 2=medium, 3=low
}

// GetBudgetRecommendations generates simple budget recommendations
// NOTE: This provides basic rule-based recommendations. For ML-based recommendations,
// use the Analytics_Model Python service
func (s *AnalyticsService) GetBudgetRecommendations(userUID string, roomspaceID *string) ([]Recommendation, error) {
	// Get last 60 days of expenses for analysis
	now := time.Now()
	sixtyDaysAgo := now.AddDate(0, 0, -60)

	expenses, err := s.getExpensesForPeriod(userUID, roomspaceID, sixtyDaysAgo, now)
	if err != nil {
		return nil, fmt.Errorf("failed to get expenses: %v", err)
	}

	if len(expenses) == 0 {
		return []Recommendation{}, nil
	}

	// Calculate category spending
	categorySpending := make(map[string]float64)
	categoryCount := make(map[string]int)

	for _, expense := range expenses {
		userAmount := s.getUserAmountFromExpense(&expense, userUID)
		categorySpending[expense.Category] += userAmount
		categoryCount[expense.Category]++
	}

	// Calculate total spending
	totalSpending := 0.0
	for _, amount := range categorySpending {
		totalSpending += amount
	}

	var recommendations []Recommendation
	recommendationID := 1

	// Simple rule-based recommendations
	for category, spending := range categorySpending {
		percentage := (spending / totalSpending) * 100.0

		// High spending category
		if percentage > 30.0 {
			suggestedLimit := spending * 0.85
			potentialSavings := spending - suggestedLimit

			recommendations = append(recommendations, Recommendation{
				ID:               fmt.Sprintf("rec_%d", recommendationID),
				Type:             "reduce_spending",
				Category:         category,
				CurrentSpending:  math.Round(spending*100) / 100,
				SuggestedLimit:   math.Round(suggestedLimit*100) / 100,
				PotentialSavings: math.Round(potentialSavings*100) / 100,
				Description:      fmt.Sprintf("Consider reducing %s spending by 15%% to save %.2f", category, potentialSavings),
				Priority:         1,
			})
			recommendationID++
		}
	}

	// Sort by potential savings
	for i := 0; i < len(recommendations); i++ {
		for j := i + 1; j < len(recommendations); j++ {
			if recommendations[j].PotentialSavings > recommendations[i].PotentialSavings {
				recommendations[i], recommendations[j] = recommendations[j], recommendations[i]
			}
		}
	}

	// Limit to top 3 recommendations
	if len(recommendations) > 3 {
		recommendations = recommendations[:3]
	}

	return recommendations, nil
}

// Anomaly represents a detected spending anomaly
type Anomaly struct {
	ExpenseID       uint    `json:"expense_id"`
	Amount          float64 `json:"amount"`
	Category        string  `json:"category"`
	AnomalyScore    float64 `json:"anomaly_score"`
	Reason          string  `json:"reason"`
	CategoryAverage float64 `json:"category_average"`
	Date            string  `json:"date"`
}

// DetectAnomalies identifies unusual spending patterns using simple statistical methods
// NOTE: This uses basic statistical analysis. For ML-based anomaly detection,
// use the Analytics_Model Python service
func (s *AnalyticsService) DetectAnomalies(userUID string, roomspaceID *string) ([]Anomaly, error) {
	// Get last 90 days of expenses for baseline
	now := time.Now()
	ninetyDaysAgo := now.AddDate(0, 0, -90)

	expenses, err := s.getExpensesForPeriod(userUID, roomspaceID, ninetyDaysAgo, now)
	if err != nil {
		return nil, fmt.Errorf("failed to get expenses: %v", err)
	}

	if len(expenses) < 10 {
		return []Anomaly{}, nil
	}

	// Calculate category statistics
	categoryAmounts := make(map[string][]float64)

	for _, expense := range expenses {
		userAmount := s.getUserAmountFromExpense(&expense, userUID)
		categoryAmounts[expense.Category] = append(categoryAmounts[expense.Category], userAmount)
	}

	// Calculate mean for each category
	categoryStats := make(map[string]struct {
		mean   float64
		stdDev float64
	})

	for category, amounts := range categoryAmounts {
		if len(amounts) < 3 {
			continue
		}

		sum := 0.0
		for _, amount := range amounts {
			sum += amount
		}
		mean := sum / float64(len(amounts))

		variance := 0.0
		for _, amount := range amounts {
			variance += math.Pow(amount-mean, 2)
		}
		stdDev := math.Sqrt(variance / float64(len(amounts)))

		categoryStats[category] = struct {
			mean   float64
			stdDev float64
		}{mean: mean, stdDev: stdDev}
	}

	// Detect anomalies (expenses > 2 standard deviations from mean)
	var anomalies []Anomaly
	thirtyDaysAgo := now.AddDate(0, 0, -30)

	for _, expense := range expenses {
		if expense.CreatedAt.Before(thirtyDaysAgo) {
			continue
		}

		userAmount := s.getUserAmountFromExpense(&expense, userUID)
		stats, exists := categoryStats[expense.Category]
		if !exists {
			continue
		}

		threshold := stats.mean + (2 * stats.stdDev)

		if userAmount > threshold && stats.stdDev > 0 {
			anomalyScore := (userAmount - stats.mean) / stats.stdDev
			reason := fmt.Sprintf("This expense is %.1f standard deviations above your average %s spending",
				anomalyScore, expense.Category)

			anomalies = append(anomalies, Anomaly{
				ExpenseID:       expense.ID,
				Amount:          math.Round(userAmount*100) / 100,
				Category:        expense.Category,
				AnomalyScore:    math.Round(anomalyScore*100) / 100,
				Reason:          reason,
				CategoryAverage: math.Round(stats.mean*100) / 100,
				Date:            expense.CreatedAt.Format("2006-01-02"),
			})
		}
	}

	// Sort by anomaly score
	for i := 0; i < len(anomalies); i++ {
		for j := i + 1; j < len(anomalies); j++ {
			if anomalies[j].AnomalyScore > anomalies[i].AnomalyScore {
				anomalies[i], anomalies[j] = anomalies[j], anomalies[i]
			}
		}
	}

	return anomalies, nil
}

// RoomspaceAnalytics represents analytics for a roomspace
type RoomspaceAnalytics struct {
	RoomspaceID         string                   `json:"roomspace_id"`
	RoomspaceName       string                   `json:"roomspace_name"`
	TotalSharedExpenses float64                  `json:"total_shared_expenses"`
	MemberContributions []MemberContribution     `json:"member_contributions"`
	CategoryBreakdown   []CategorySpend          `json:"category_breakdown"`
	TimeRange           TimeRange                `json:"time_range"`
}

// MemberContribution represents a member's contribution to roomspace expenses
type MemberContribution struct {
	UserUID         string  `json:"user_uid"`
	UserName        string  `json:"user_name"`
	TotalPaid       float64 `json:"total_paid"`       // Amount they paid for expenses
	TotalOwed       float64 `json:"total_owed"`       // Amount they owe from splits
	NetContribution float64 `json:"net_contribution"` // TotalPaid - TotalOwed
	Percentage      float64 `json:"percentage"`       // Percentage of total shared expenses
}

// TimeRange represents the time period for analytics
type TimeRange struct {
	StartDate string `json:"start_date"`
	EndDate   string `json:"end_date"`
}

// GetRoomspaceAnalytics calculates analytics for a specific roomspace
func (s *AnalyticsService) GetRoomspaceAnalytics(roomspaceID string, startDate, endDate time.Time) (*RoomspaceAnalytics, error) {
	// Get all expenses for the roomspace in the time period
	// Only shared expenses (those with roomspace_id) are included
	var expenses []models.Expense

	query := config.DB.Where("roomspace_id = ? AND created_at >= ? AND created_at <= ?", 
		roomspaceID, startDate, endDate)
	query = query.Preload("Splits").Preload("Splits.User").Preload("Payer")

	if err := query.Find(&expenses).Error; err != nil {
		return nil, fmt.Errorf("failed to get roomspace expenses: %v", err)
	}

	// Get roomspace details
	var roomspace models.Roomspace
	if err := config.DB.Where("id = ?", roomspaceID).First(&roomspace).Error; err != nil {
		return nil, fmt.Errorf("failed to get roomspace: %v", err)
	}

	// Calculate total shared expenses
	totalSharedExpenses := 0.0
	for _, expense := range expenses {
		totalSharedExpenses += expense.Amount
	}

	// Calculate member contributions
	memberStats := make(map[string]*MemberContribution)

	for _, expense := range expenses {
		// Track what each member paid
		if _, exists := memberStats[expense.PaidBy]; !exists {
			userName := "Unknown"
			if expense.Payer != nil {
				userName = expense.Payer.Name
			}
			memberStats[expense.PaidBy] = &MemberContribution{
				UserUID:  expense.PaidBy,
				UserName: userName,
			}
		}
		memberStats[expense.PaidBy].TotalPaid += expense.Amount

		// Track what each member owes from splits
		for _, split := range expense.Splits {
			if _, exists := memberStats[split.UserUID]; !exists {
				userName := "Unknown"
				if split.User != nil {
					userName = split.User.Name
				}
				memberStats[split.UserUID] = &MemberContribution{
					UserUID:  split.UserUID,
					UserName: userName,
				}
			}
			memberStats[split.UserUID].TotalOwed += split.Amount
		}
	}

	// Calculate net contributions and percentages
	var contributions []MemberContribution
	for _, member := range memberStats {
		member.NetContribution = member.TotalPaid - member.TotalOwed
		if totalSharedExpenses > 0 {
			member.Percentage = (member.TotalOwed / totalSharedExpenses) * 100.0
		}
		
		// Round values
		member.TotalPaid = math.Round(member.TotalPaid*100) / 100
		member.TotalOwed = math.Round(member.TotalOwed*100) / 100
		member.NetContribution = math.Round(member.NetContribution*100) / 100
		member.Percentage = math.Round(member.Percentage*100) / 100
		
		contributions = append(contributions, *member)
	}

	// Sort contributions by total owed (descending)
	for i := 0; i < len(contributions); i++ {
		for j := i + 1; j < len(contributions); j++ {
			if contributions[j].TotalOwed > contributions[i].TotalOwed {
				contributions[i], contributions[j] = contributions[j], contributions[i]
			}
		}
	}

	// Calculate category breakdown for shared expenses
	categoryTotals := make(map[string]*CategorySpend)
	for _, expense := range expenses {
		if _, exists := categoryTotals[expense.Category]; !exists {
			categoryTotals[expense.Category] = &CategorySpend{
				Category: expense.Category,
				Amount:   0,
				Count:    0,
			}
		}
		categoryTotals[expense.Category].Amount += expense.Amount
		categoryTotals[expense.Category].Count++
	}

	// Calculate percentages and convert to slice
	categoryBreakdown := s.calculateCategoryPercentages(categoryTotals, totalSharedExpenses)

	return &RoomspaceAnalytics{
		RoomspaceID:         roomspaceID,
		RoomspaceName:       roomspace.Name,
		TotalSharedExpenses: math.Round(totalSharedExpenses*100) / 100,
		MemberContributions: contributions,
		CategoryBreakdown:   categoryBreakdown,
		TimeRange: TimeRange{
			StartDate: startDate.Format("2006-01-02"),
			EndDate:   endDate.Format("2006-01-02"),
		},
	}, nil
}
