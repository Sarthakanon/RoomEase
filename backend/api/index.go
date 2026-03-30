package handler

import (
	"net/http"
	"roomease/backend/config"
	"roomease/backend/handlers"
	"roomease/backend/middleware"
	"roomease/backend/services"

	"github.com/gin-gonic/gin"
)

func Handler(w http.ResponseWriter, r *http.Request) {
	// Initialize configuration
	cfg := config.LoadConfig()

	// Initialize Firebase (ignore errors for serverless)
	config.InitFirebase(cfg.FirebaseCredentialPath)

	// Initialize PostgreSQL
	var dbService *services.PostgresService
	if err := config.InitPostgreSQL(cfg.PostgresDatabaseURL); err != nil {
		// Continue without database for now
		dbService = nil
	} else {
		dbService = services.NewPostgresService()
	}

	// Set Gin to release mode for production
	gin.SetMode(gin.ReleaseMode)

	// Create Gin router
	router := gin.New()
	router.Use(gin.Logger())
	router.Use(gin.Recovery())

	// Add CORS middleware with allowed origins
	router.Use(middleware.CORSMiddleware(cfg.AllowedOrigins))

	// Health check
	router.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "RoomEase Backend"})
	})

	// Initialize services
	sessionStore := services.NewSessionStore()
	analyticsService := services.NewAnalyticsService()
	balanceService := services.NewBalanceService()
	paymentService := services.NewPaymentConfirmationService()

	// Initialize handlers with proper dependencies
	authHandler := handlers.NewAuthHandler(sessionStore, dbService)
	userHandler := handlers.NewUserHandler(dbService)
	roomspaceHandler := handlers.NewRoomspaceHandler(dbService)
	expenseHandler := handlers.NewExpenseHandler(dbService)
	notificationHandler := handlers.NewNotificationHandler(dbService)
	analyticsHandler := handlers.NewAnalyticsHandler(analyticsService, dbService)
	balanceHandler := handlers.NewBalanceHandler(balanceService, dbService)
	paymentHandler := handlers.NewPaymentConfirmationHandler(paymentService, dbService)
	adminHandler := handlers.NewAdminHandler()

	// Public routes
	router.POST("/api/auth/login", authHandler.Login)

	// Admin routes (no auth required for testing)
	router.GET("/api/admin/stats", adminHandler.GetSystemStats)
	router.GET("/api/admin/users", adminHandler.GetAllUsers)
	router.GET("/api/admin/users/:userId", adminHandler.GetUserDetails)
	router.POST("/api/admin/users/:userId/ban", adminHandler.BanUser)
	router.POST("/api/admin/users/:userId/unban", adminHandler.UnbanUser)
	router.GET("/api/admin/users/:userId/ban-status", adminHandler.CheckUserBanStatus)

	// Protected routes
	protected := router.Group("/api")
	protected.Use(middleware.AuthMiddleware())
	{
		// Auth routes
		protected.POST("/auth/logout", authHandler.Logout)
		protected.GET("/auth/verify", authHandler.Verify)
		protected.POST("/auth/refresh", authHandler.Refresh)

		// User routes
		protected.GET("/user/profile", userHandler.GetProfile)
		protected.PUT("/user/profile", userHandler.UpdateProfile)
		protected.GET("/user/roomspaces/count", roomspaceHandler.GetRoomspaceCount)

		// Roomspace routes
		protected.GET("/roomspaces", roomspaceHandler.GetRoomspaces)
		protected.POST("/roomspaces", roomspaceHandler.CreateRoomspace)
		protected.GET("/roomspaces/:id", roomspaceHandler.GetRoomspace)
		protected.POST("/roomspaces/:id/join", roomspaceHandler.JoinRoomspace)
		protected.GET("/roomspaces/code/:code", roomspaceHandler.SearchRoomspaceByCode)
		protected.POST("/roomspaces/code/:code/join", roomspaceHandler.JoinRoomspaceByCode)
		protected.DELETE("/roomspaces/:id/members", roomspaceHandler.RemoveMember)

		// Expense routes
		protected.POST("/expenses", expenseHandler.CreateExpense)
		protected.GET("/expenses", expenseHandler.GetExpenses)
		protected.GET("/expenses/:id", expenseHandler.GetExpenseByID)
		protected.PUT("/expenses/:id", expenseHandler.UpdateExpense)
		protected.DELETE("/expenses/:id", expenseHandler.DeleteExpense)
		protected.GET("/roomspaces/:id/expenses", expenseHandler.GetRoomspaceExpenses)
		protected.GET("/roomspaces/:id/expenses/recent", expenseHandler.GetRecentExpenses)

		// Personal expenses
		protected.POST("/personal-expenses", expenseHandler.CreatePersonalExpense)
		protected.GET("/personal-expenses", expenseHandler.GetPersonalExpenses)
		protected.DELETE("/personal-expenses/:id", expenseHandler.DeletePersonalExpense)

		// Analytics routes
		protected.GET("/analytics/summary", analyticsHandler.GetSummary)
		protected.GET("/analytics/trends", analyticsHandler.GetTrends)
		protected.GET("/analytics/predictions", analyticsHandler.GetPredictions)
		protected.GET("/analytics/patterns", analyticsHandler.GetPatterns)
		protected.GET("/analytics/anomalies", analyticsHandler.GetAnomalies)
		protected.GET("/analytics/recommendations", analyticsHandler.GetRecommendations)
		protected.GET("/analytics/roomspace/:id", analyticsHandler.GetRoomspaceAnalytics)
		protected.POST("/analytics/feedback", analyticsHandler.SubmitFeedback)

		// Balance routes
		protected.GET("/roomspaces/:id/balances", balanceHandler.GetRoomspaceBalances)
		protected.GET("/roomspaces/:id/balances/:userId", balanceHandler.GetUserBalance)
		protected.POST("/roomspaces/:id/settlements", balanceHandler.CreateSettlement)
		protected.GET("/roomspaces/:id/settlements", balanceHandler.GetSettlementHistory)
		protected.GET("/roomspaces/:id/settlements/suggestions", balanceHandler.GetSettlementSuggestions)
		protected.POST("/roomspaces/:id/balances/refresh", balanceHandler.RefreshBalanceCache)

		// Payment confirmation routes
		protected.POST("/roomspaces/:id/payments/confirm", paymentHandler.CreatePaymentConfirmation)
		protected.PUT("/roomspaces/:id/payments/:paymentId/confirm", paymentHandler.ConfirmPayment)
		protected.PUT("/roomspaces/:id/payments/:paymentId/reject", paymentHandler.RejectPayment)
		protected.GET("/roomspaces/:id/payments/pending", paymentHandler.GetPendingConfirmations)
		protected.GET("/roomspaces/:id/payments/history", paymentHandler.GetPaymentHistory)
		protected.GET("/roomspaces/:id/payments/stats", paymentHandler.GetPaymentStats)

		// Notification routes
		protected.GET("/notifications", notificationHandler.GetNotifications)
		protected.POST("/notifications/send-reminder", notificationHandler.SendPaymentReminder)
		protected.PUT("/notifications/:id/read", notificationHandler.MarkAsRead)
		protected.GET("/join-requests", notificationHandler.GetJoinRequests)
		protected.GET("/join-requests/pending", notificationHandler.GetPendingJoinRequest)
		protected.POST("/join-requests/:id/process", notificationHandler.ProcessJoinRequest)
	}

	// Handle the request
	router.ServeHTTP(w, r)
}