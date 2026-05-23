package services

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"net/http"
	"roomease/backend/config"
	"roomease/backend/models"
	"strings"
	"time"
)

// AnalyticsService handles analytics operations
type AnalyticsService struct {
	dbService *PostgresService
	mlAPIURL  string
}

// NewAnalyticsService creates a new analytics service
func NewAnalyticsService(dbService *PostgresService) *AnalyticsService {
	// Get ML API configuration
	mlConfig := config.GetMLConfig()

	return &AnalyticsService{
		dbService: dbService,
		mlAPIURL:  mlConfig.APIURL,
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

// MLExpense represents expense data for ML API
type MLExpense struct {
	ID       uint    `json:"id"`
	Amount   float64 `json:"amount"`
	Category string  `json:"category"`
	Date     string  `json:"date"`
	UserUID  string  `json:"user_uid"`
}

// MLPredictionResponse represents ML API prediction response
type MLPredictionResponse struct {
	Success          bool           `json:"success"`
	Predictions      []MLPrediction `json:"predictions"`
	InsufficientData bool           `json:"insufficient_data"`
}

// MLPrediction represents a single ML prediction
type MLPrediction struct {
	Category        string  `json:"category"`
	PredictedAmount float64 `json:"predicted_amount"`
	ConfidenceLow   float64 `json:"confidence_low"`
	ConfidenceHigh  float64 `json:"confidence_high"`
	HistoricalAvg   float64 `json:"historical_avg"`
	MLConfidence    float64 `json:"ml_confidence"`
}

// MLRecommendationResponse represents ML API recommendation response
type MLRecommendationResponse struct {
	Success         bool               `json:"success"`
	Recommendations []MLRecommendation `json:"recommendations"`
}

// MLRecommendation represents a single ML recommendation
type MLRecommendation struct {
	ID               string  `json:"id"`
	Type             string  `json:"type"`
	Category         string  `json:"category"`
	CurrentSpending  float64 `json:"current_spending"`
	SuggestedLimit   float64 `json:"suggested_limit"`
	PotentialSavings float64 `json:"potential_savings"`
	Description      string  `json:"description"`
	Priority         int     `json:"priority"`
	MLConfidence     float64 `json:"ml_confidence"`
}

// MLAnomalyResponse represents ML API anomaly response
type MLAnomalyResponse struct {
	Success   bool        `json:"success"`
	Anomalies []MLAnomaly `json:"anomalies"`
}

// MLAnomaly represents a single ML anomaly
type MLAnomaly struct {
	ExpenseID       uint    `json:"expense_id"`
	Amount          float64 `json:"amount"`
	Category        string  `json:"category"`
	AnomalyScore    float64 `json:"anomaly_score"`
	Reason          string  `json:"reason"`
	CategoryAverage float64 `json:"category_average"`
	Date            string  `json:"date"`
	MLConfidence    float64 `json:"ml_confidence"`
}

// callMLAPI makes HTTP requests to the ML API
func (s *AnalyticsService) callMLAPI(endpoint string, payload interface{}) ([]byte, error) {
	jsonData, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal payload: %v", err)
	}

	url := s.mlAPIURL + endpoint
	resp, err := http.Post(url, "application/json", bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, fmt.Errorf("failed to call ML API: %v", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read ML API response: %v", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("ML API returned error: %s", string(body))
	}

	return body, nil
}

// convertExpensesToMLFormat converts database expenses to ML API format
func (s *AnalyticsService) convertExpensesToMLFormat(expenses []models.Expense, userUID string) []MLExpense {
	var mlExpenses []MLExpense

	for _, expense := range expenses {
		// Get user's amount from splits
		userAmount := s.getUserAmountFromExpense(&expense, userUID)
		if userAmount > 0 {
			mlExpenses = append(mlExpenses, MLExpense{
				ID:       expense.ID,
				Amount:   userAmount,
				Category: expense.Category,
				Date:     expense.CreatedAt.Format("2006-01-02"),
				UserUID:  userUID,
			})
		}
	}

	return mlExpenses
}

// GetSpendingSummary calculates spending summary for a user with ML enhancements
func (s *AnalyticsService) GetSpendingSummary(userUID string, roomspaceID *string, startDate, endDate time.Time) (*AnalyticsSummary, error) {
	// Get expenses for the period
	expenses, err := s.getExpensesForPeriod(userUID, roomspaceID, startDate, endDate)
	if err != nil {
		return nil, fmt.Errorf("failed to get expenses: %v", err)
	}

	// Calculate basic summary
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

	// Calculate percentages
	topCategories := s.calculateCategoryPercentages(categoryTotals, totalSpent)

	// Calculate spending trend
	trend := s.calculateSpendingTrend(userUID, roomspaceID, endDate)

	summary := &AnalyticsSummary{
		TotalSpent:         totalSpent,
		PredictedNextMonth: 0, // Will be set by ML prediction service
		SavingsPotential:   0, // Will be set by ML recommendation engine
		TopCategories:      topCategories,
		SpendingTrend:      trend,
	}

	// Try to get ML predictions for next month
	if len(expenses) >= 5 {
		mlExpenses := s.convertExpensesToMLFormat(expenses, userUID)
		predictions, err := s.getMLPredictions(userUID, roomspaceID, mlExpenses)
		if err == nil && !predictions.InsufficientData {
			totalPredicted := 0.0
			for _, pred := range predictions.Predictions {
				totalPredicted += pred.PredictedAmount
			}
			summary.PredictedNextMonth = totalPredicted
		}
	}

	// Try to get ML recommendations for savings potential
	if len(expenses) >= 5 {
		mlExpenses := s.convertExpensesToMLFormat(expenses, userUID)
		recommendations, err := s.getMLRecommendations(userUID, roomspaceID, mlExpenses)
		if err == nil {
			totalSavings := 0.0
			for _, rec := range recommendations.Recommendations {
				totalSavings += rec.PotentialSavings
			}
			summary.SavingsPotential = totalSavings
		}
	}

	return summary, nil
}

// getMLPredictions calls the ML API for predictions
func (s *AnalyticsService) getMLPredictions(userUID string, roomspaceID *string, expenses []MLExpense) (*MLPredictionResponse, error) {
	payload := map[string]interface{}{
		"user_id":  userUID,
		"expenses": expenses,
	}
	if roomspaceID != nil {
		payload["roomspace_id"] = *roomspaceID
	}

	body, err := s.callMLAPI("/api/ml/predictions", payload)
	if err != nil {
		return nil, err
	}

	var response MLPredictionResponse
	if err := json.Unmarshal(body, &response); err != nil {
		return nil, fmt.Errorf("failed to unmarshal ML prediction response: %v", err)
	}

	return &response, nil
}

// getMLRecommendations calls the ML API for recommendations
func (s *AnalyticsService) getMLRecommendations(userUID string, roomspaceID *string, expenses []MLExpense) (*MLRecommendationResponse, error) {
	payload := map[string]interface{}{
		"user_id":  userUID,
		"expenses": expenses,
	}
	if roomspaceID != nil {
		payload["roomspace_id"] = *roomspaceID
	}

	body, err := s.callMLAPI("/api/ml/recommendations", payload)
	if err != nil {
		return nil, err
	}

	var response MLRecommendationResponse
	if err := json.Unmarshal(body, &response); err != nil {
		return nil, fmt.Errorf("failed to unmarshal ML recommendation response: %v", err)
	}

	return &response, nil
}

// getMLAnomalies calls the ML API for anomaly detection
func (s *AnalyticsService) getMLAnomalies(userUID string, roomspaceID *string, expenses []MLExpense) (*MLAnomalyResponse, error) {
	payload := map[string]interface{}{
		"user_id":  userUID,
		"expenses": expenses,
	}
	if roomspaceID != nil {
		payload["roomspace_id"] = *roomspaceID
	}

	body, err := s.callMLAPI("/api/ml/anomalies", payload)
	if err != nil {
		return nil, err
	}

	var response MLAnomalyResponse
	if err := json.Unmarshal(body, &response); err != nil {
		return nil, fmt.Errorf("failed to unmarshal ML anomaly response: %v", err)
	}

	return &response, nil
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
		query = query.Preload("Splits").Order("created_at DESC")
		if err := query.Find(&expenses).Error; err != nil {
			return nil, err
		}
		return expenses, nil
	} else {
		// Personal analytics mode:
		// 1) Shared/roomspace expenses where user has a split.
		query = query.Where("id IN (SELECT expense_id FROM expense_splits WHERE user_uid = ?)", userUID)
		query = query.Preload("Splits").Order("created_at DESC")
		if err := query.Find(&expenses).Error; err != nil {
			return nil, err
		}

		// 2) Personal expenses owned by this user, mapped into compatible expense shape.
		var personalExpenses []models.PersonalExpense
		if err := config.DB.Where("user_uid = ? AND created_at >= ? AND created_at <= ?", userUID, startDate, endDate).
			Order("created_at DESC").
			Find(&personalExpenses).Error; err != nil {
			return nil, err
		}

		for _, personal := range personalExpenses {
			expenses = append(expenses, models.Expense{
				ID:          personal.ID,
				RoomspaceID: "",
				Title:       personal.Title,
				Description: personal.Description,
				Amount:      personal.Amount,
				Category:    personal.Category,
				PaidBy:      personal.UserUID,
				SplitType:   models.SplitTypeExact,
				CreatedAt:   personal.CreatedAt,
				UpdatedAt:   personal.UpdatedAt,
				Splits: []models.ExpenseSplit{
					{
						ExpenseID: personal.ID,
						UserUID:   personal.UserUID,
						Amount:    personal.Amount,
						CreatedAt: personal.CreatedAt,
					},
				},
			})
		}

		return expenses, nil
	}
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

// GetSpendingPredictions generates ML-based spending predictions for the next month
func (s *AnalyticsService) GetSpendingPredictions(userUID string, roomspaceID *string) (*PredictionResult, error) {
	// Get last 60 days of expenses for ML analysis
	now := time.Now()
	sixtyDaysAgo := now.AddDate(0, 0, -60)

	expenses, err := s.getExpensesForPeriod(userUID, roomspaceID, sixtyDaysAgo, now)
	if err != nil {
		return nil, fmt.Errorf("failed to get expenses: %v", err)
	}

	// Check if we have enough data
	if len(expenses) < 5 {
		return &PredictionResult{
			Predictions:      []SpendingPrediction{},
			InsufficientData: true,
			DataDays:         0,
			Message:          "Need at least 5 expenses for ML predictions",
		}, nil
	}

	// Convert to ML format
	mlExpenses := s.convertExpensesToMLFormat(expenses, userUID)

	// Try ML predictions first
	mlResponse, err := s.getMLPredictions(userUID, roomspaceID, mlExpenses)
	if err == nil && !mlResponse.InsufficientData {
		// Convert ML predictions to our format
		var predictions []SpendingPrediction
		for _, mlPred := range mlResponse.Predictions {
			predictions = append(predictions, SpendingPrediction{
				Category:        mlPred.Category,
				PredictedAmount: mlPred.PredictedAmount,
				ConfidenceLow:   mlPred.ConfidenceLow,
				ConfidenceHigh:  mlPred.ConfidenceHigh,
				HistoricalAvg:   mlPred.HistoricalAvg,
			})
		}

		return &PredictionResult{
			Predictions:      predictions,
			InsufficientData: false,
			DataDays:         60,
			Message:          "ML-powered predictions",
		}, nil
	}

	// ML-only mode: do not fallback to statistical predictions.
	return nil, fmt.Errorf("ml predictions unavailable")
}

// getStatisticalPredictions provides fallback statistical predictions
func (s *AnalyticsService) getStatisticalPredictions(userUID string, roomspaceID *string, expenses []models.Expense) (*PredictionResult, error) {
	// Calculate actual days of data
	now := time.Now()
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

	// Simple prediction based on historical average
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
		Message:          "Statistical predictions (ML unavailable)",
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

// GetBudgetRecommendations generates ML-enhanced budget recommendations
func (s *AnalyticsService) GetBudgetRecommendations(userUID string, roomspaceID *string) ([]Recommendation, error) {
	// Get last 60 days of expenses for ML analysis
	now := time.Now()
	sixtyDaysAgo := now.AddDate(0, 0, -60)

	expenses, err := s.getExpensesForPeriod(userUID, roomspaceID, sixtyDaysAgo, now)
	if err != nil {
		return nil, fmt.Errorf("failed to get expenses: %v", err)
	}

	if len(expenses) < 5 {
		return []Recommendation{}, nil
	}

	// Convert to ML format
	mlExpenses := s.convertExpensesToMLFormat(expenses, userUID)

	// Try ML recommendations first
	mlResponse, err := s.getMLRecommendations(userUID, roomspaceID, mlExpenses)
	if err == nil && len(mlResponse.Recommendations) > 0 {
		// Convert ML recommendations to our format
		var recommendations []Recommendation
		for _, mlRec := range mlResponse.Recommendations {
			recommendations = append(recommendations, Recommendation{
				ID:               mlRec.ID,
				Type:             "ml_" + mlRec.Type,
				Category:         mlRec.Category,
				CurrentSpending:  mlRec.CurrentSpending,
				SuggestedLimit:   mlRec.SuggestedLimit,
				PotentialSavings: mlRec.PotentialSavings,
				Description:      mlRec.Description,
				Priority:         mlRec.Priority,
			})
		}

		return recommendations, nil
	}

	// ML-only mode: do not fallback to rule-based recommendations.
	return nil, fmt.Errorf("ml recommendations unavailable")
}

// getRuleBasedRecommendations provides fallback rule-based recommendations
func (s *AnalyticsService) getRuleBasedRecommendations(userUID string, roomspaceID *string, expenses []models.Expense) ([]Recommendation, error) {
	thirtyDaysAgo := time.Now().AddDate(0, 0, -30)

	// Calculate category spending for last 60 days and last 30 days
	categorySpending60 := make(map[string]float64)
	categorySpending30 := make(map[string]float64)
	categoryCount := make(map[string]int)

	for _, expense := range expenses {
		userAmount := s.getUserAmountFromExpense(&expense, userUID)
		categorySpending60[expense.Category] += userAmount
		categoryCount[expense.Category]++

		// Track last 30 days separately for trend analysis
		if expense.CreatedAt.After(thirtyDaysAgo) {
			categorySpending30[expense.Category] += userAmount
		}
	}

	// Calculate total spending
	totalSpending := 0.0
	for _, amount := range categorySpending60 {
		totalSpending += amount
	}

	var recommendations []Recommendation
	recommendationID := 1

	// Enhanced category-specific recommendations
	for category, spending60 := range categorySpending60 {
		percentage := (spending60 / totalSpending) * 100.0
		spending30 := categorySpending30[category]

		// Calculate monthly average
		monthlyAvg := spending60 / 2.0 // 60 days = ~2 months

		// Determine trend
		trend := "stable"
		if spending30 > monthlyAvg*1.15 {
			trend = "increasing"
		} else if spending30 < monthlyAvg*0.85 {
			trend = "decreasing"
		}

		// Generate recommendations for high spending categories
		if percentage > 25.0 || (trend == "increasing" && percentage > 15.0) {
			priority := 2 // Moderate
			if percentage > 35.0 {
				priority = 1 // Critical
			} else if percentage < 20.0 {
				priority = 3 // Low
			}

			suggestedLimit := monthlyAvg * 0.80 // 20% reduction target
			potentialSavings := monthlyAvg - suggestedLimit

			// Generate category-specific actionable tips
			description := s.generateCategoryRecommendation(category, monthlyAvg, potentialSavings, trend)

			recommendations = append(recommendations, Recommendation{
				ID:               fmt.Sprintf("rec_%d", recommendationID),
				Type:             "reduce_spending",
				Category:         category,
				CurrentSpending:  math.Round(monthlyAvg*100) / 100,
				SuggestedLimit:   math.Round(suggestedLimit*100) / 100,
				PotentialSavings: math.Round(potentialSavings*100) / 100,
				Description:      description,
				Priority:         priority,
			})
			recommendationID++
		}
	}

	// Sort by priority (1=highest) then by potential savings
	for i := 0; i < len(recommendations); i++ {
		for j := i + 1; j < len(recommendations); j++ {
			if recommendations[j].Priority < recommendations[i].Priority ||
				(recommendations[j].Priority == recommendations[i].Priority &&
					recommendations[j].PotentialSavings > recommendations[i].PotentialSavings) {
				recommendations[i], recommendations[j] = recommendations[j], recommendations[i]
			}
		}
	}

	// Limit to top 5 recommendations
	if len(recommendations) > 5 {
		recommendations = recommendations[:5]
	}

	return recommendations, nil
}

// generateCategoryRecommendation creates actionable, category-specific recommendations
func (s *AnalyticsService) generateCategoryRecommendation(category string, currentSpending, potentialSavings float64, trend string) string {
	trendEmoji := "→"
	if trend == "increasing" {
		trendEmoji = "↑"
	} else if trend == "decreasing" {
		trendEmoji = "↓"
	}

	categoryLower := strings.ToLower(category)

	// Category-specific actionable recommendations
	if strings.Contains(categoryLower, "food") || strings.Contains(categoryLower, "groceries") {
		return fmt.Sprintf("%s Food spending is high. Try: Cook 2-3 more meals at home weekly, buy in bulk with roommates, meal prep on weekends, use grocery apps for discounts. Target: Save Rs. %.0f/month", trendEmoji, potentialSavings)
	}

	if strings.Contains(categoryLower, "utilities") || strings.Contains(categoryLower, "bill") {
		return fmt.Sprintf("%s Utility costs are high. Try: Turn off unused appliances, use energy-efficient bulbs, set AC to 24°C, share internet/streaming costs with roommates. Target: Save Rs. %.0f/month", trendEmoji, potentialSavings)
	}

	if strings.Contains(categoryLower, "transport") || strings.Contains(categoryLower, "travel") {
		return fmt.Sprintf("%s Transport costs are high. Try: Carpool with roommates, use public transport, get monthly passes, combine errands into single trips. Target: Save Rs. %.0f/month", trendEmoji, potentialSavings)
	}

	if strings.Contains(categoryLower, "entertainment") {
		return fmt.Sprintf("%s Entertainment spending is high. Try: Share streaming subscriptions, look for free events, use student discounts, limit dining out to 2x/week. Target: Save Rs. %.0f/month", trendEmoji, potentialSavings)
	}

	if strings.Contains(categoryLower, "rent") {
		return fmt.Sprintf("%s Rent is a major expense. Consider: Negotiating with landlord, finding additional roommates, moving to a more affordable area, or subletting unused space. Potential: Save Rs. %.0f/month", trendEmoji, potentialSavings)
	}

	// Generic recommendation for other categories
	return fmt.Sprintf("%s %s spending is %.0f%% of your budget. Try: Track expenses daily, set category limits, find cheaper alternatives, delay non-urgent purchases. Target: Save Rs. %.0f/month",
		trendEmoji, category, (currentSpending/potentialSavings)*100, potentialSavings)
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

// DetectAnomalies identifies unusual spending patterns using ML-enhanced detection
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

	// Convert to ML format
	mlExpenses := s.convertExpensesToMLFormat(expenses, userUID)

	// Try ML anomaly detection first
	mlResponse, err := s.getMLAnomalies(userUID, roomspaceID, mlExpenses)
	if err == nil && len(mlResponse.Anomalies) > 0 {
		// Convert ML anomalies to our format
		var anomalies []Anomaly
		for _, mlAnomaly := range mlResponse.Anomalies {
			anomalies = append(anomalies, Anomaly{
				ExpenseID:       mlAnomaly.ExpenseID,
				Amount:          mlAnomaly.Amount,
				Category:        mlAnomaly.Category,
				AnomalyScore:    mlAnomaly.AnomalyScore,
				Reason:          mlAnomaly.Reason,
				CategoryAverage: mlAnomaly.CategoryAverage,
				Date:            mlAnomaly.Date,
			})
		}

		return anomalies, nil
	}

	// ML-only mode: do not fallback to statistical anomaly detection.
	return nil, fmt.Errorf("ml anomalies unavailable")
}

// getStatisticalAnomalies provides fallback statistical anomaly detection
func (s *AnalyticsService) getStatisticalAnomalies(expenses []models.Expense) ([]Anomaly, error) {
	// Calculate category statistics
	categoryAmounts := make(map[string][]float64)

	for _, expense := range expenses {
		userAmount := s.getUserAmountFromExpense(&expense, expense.PaidBy) // Use PaidBy as fallback
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
	thirtyDaysAgo := time.Now().AddDate(0, 0, -30)

	for _, expense := range expenses {
		if expense.CreatedAt.Before(thirtyDaysAgo) {
			continue
		}

		userAmount := s.getUserAmountFromExpense(&expense, expense.PaidBy)
		stats, exists := categoryStats[expense.Category]
		if !exists {
			continue
		}

		threshold := stats.mean + (2 * stats.stdDev)

		if userAmount > threshold && stats.stdDev > 0 {
			anomalyScore := (userAmount - stats.mean) / stats.stdDev
			reason := fmt.Sprintf("Statistical analysis: %.1f standard deviations above average %s spending",
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
	RoomspaceID         string               `json:"roomspace_id"`
	RoomspaceName       string               `json:"roomspace_name"`
	TotalSharedExpenses float64              `json:"total_shared_expenses"`
	MemberContributions []MemberContribution `json:"member_contributions"`
	CategoryBreakdown   []CategorySpend      `json:"category_breakdown"`
	TimeRange           TimeRange            `json:"time_range"`
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
