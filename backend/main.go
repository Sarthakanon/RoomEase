package main

import (
	"log"
	"roomease/backend/config"
	"roomease/backend/handlers"
	"roomease/backend/middleware"
	"roomease/backend/services"

	"github.com/gin-gonic/gin"
)

func main() {
	log.Println("🚀 RoomEase Backend Server")
	log.Println("Setting up...")

	// Load configuration
	cfg := config.LoadConfig()

	// Initialize Firebase
	if err := config.InitFirebase(cfg.FirebaseCredentialPath); err != nil {
		log.Fatalf("Failed to initialize Firebase: %v", err)
	}

	// Initialize PostgreSQL (non-fatal for development)
	var dbService *services.PostgresService
	if err := config.InitPostgreSQL(cfg.PostgresDatabaseURL); err != nil {
		log.Printf("⚠️  WARNING: Failed to initialize PostgreSQL: %v", err)
		log.Println("⚠️  Server will start WITHOUT database connectivity")
		log.Println("⚠️  Database-dependent endpoints will not work")
	} else {
		defer config.ClosePostgreSQL()
		
		// Initialize services
		dbService = services.NewPostgresService()

		// Run database migrations
		if err := dbService.AutoMigrate(); err != nil {
			log.Printf("⚠️  WARNING: Failed to run migrations: %v", err)
		} else {
			log.Println("✅ Database migrations completed successfully")
			
			// Cleanup expired analytics cache on startup
			analyticsCacheService := services.NewAnalyticsCacheService(dbService)
			if err := analyticsCacheService.CleanupExpiredCache(); err != nil {
				log.Printf("⚠️  WARNING: Failed to cleanup expired cache: %v", err)
			} else {
				log.Println("✅ Expired analytics cache cleaned up")
			}
		}
	}

	// Initialize session store
	sessionStore := services.NewInMemorySessionStore()
	middleware.SessionStore = sessionStore
	
	// Initialize roomspace service for middleware
	if dbService != nil {
		middleware.RoomspaceService = dbService
	}

	// Create Gin router
	router := gin.Default()

	// Add CORS middleware
	router.Use(middleware.CORSMiddleware(cfg.AllowedOrigins))

	// Add logging middleware
	router.Use(middleware.LoggerMiddleware())

	// Initialize handlers
	authHandler := handlers.NewAuthHandler(sessionStore, dbService)
	userHandler := handlers.NewUserHandler(dbService)
	roomspaceHandler := handlers.NewRoomspaceHandler(dbService)
	notificationHandler := handlers.NewNotificationHandler(dbService)
	expenseHandler := handlers.NewExpenseHandler(dbService)
	expenseDeletionHandler := handlers.NewExpenseDeletionHandler(dbService)
	expenseHistoryHandler := handlers.NewExpenseHistoryHandler(dbService)
	paymentNotificationHandler := handlers.NewPaymentNotificationHandler(dbService)
	healthHandler := handlers.NewHealthHandler()
	
	// Initialize analytics service and handler
	analyticsService := services.NewAnalyticsService(dbService)
	analyticsHandler := handlers.NewAnalyticsHandler(analyticsService, dbService)
	
	// Initialize balance service and handler
	balanceService := services.NewBalanceService()
	balanceHandler := handlers.NewBalanceHandler(balanceService, dbService)
	
	// Initialize payment confirmation service and handler
	paymentConfirmationService := services.NewPaymentConfirmationService(config.DB, balanceService, dbService)
	paymentConfirmationHandler := handlers.NewPaymentConfirmationHandler(paymentConfirmationService, dbService)
	
	// Initialize recurring expense handler
	recurringExpenseHandler := handlers.NewRecurringExpenseHandler(dbService)
	
	// Initialize eSewa handler
	esewaHandler := handlers.NewEsewaHandler(dbService)
	
	// Initialize subscription handler
	subscriptionHandler := handlers.NewSubscriptionHandler(dbService)
	
	// Initialize admin handler
	adminHandler := handlers.NewAdminHandler()

	// Health check endpoint (public)
	router.GET("/health", healthHandler.Check)

	// Public routes
	router.POST("/api/auth/login", authHandler.Login)
	
	// Public admin routes (no auth required for now - add admin auth later)
	adminRoutes := router.Group("/api/admin")
	{
		adminRoutes.GET("/stats", adminHandler.GetSystemStats)
		adminRoutes.GET("/users", adminHandler.GetAllUsers)
		adminRoutes.GET("/users/:userId", adminHandler.GetUserDetails)
		adminRoutes.POST("/users/:userId/ban", adminHandler.BanUser)
		adminRoutes.POST("/users/:userId/unban", adminHandler.UnbanUser)
		adminRoutes.GET("/users/:userId/ban-status", adminHandler.CheckUserBanStatus)
		
		// Roomspace admin routes
		adminRoutes.GET("/roomspaces", adminHandler.GetAllRoomspaces)
		adminRoutes.GET("/roomspaces/:roomspaceId", adminHandler.GetRoomspaceDetails)
		
		// Expense admin routes
		adminRoutes.GET("/expenses", adminHandler.GetAllExpenses)
		adminRoutes.GET("/personal-expenses", adminHandler.GetAllPersonalExpenses)
		
		// Analytics routes
		adminRoutes.GET("/analytics", adminHandler.GetAnalyticsData)
	}

	// Protected routes (require authentication)
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
		protected.GET("/roomspaces/:id", middleware.ValidateRoomspaceMembership(), roomspaceHandler.GetRoomspace)
		protected.POST("/roomspaces/:id/join", roomspaceHandler.JoinRoomspace)
		protected.POST("/roomspaces/:id/leave", middleware.ValidateRoomspaceMembership(), roomspaceHandler.LeaveRoomspace)
		protected.GET("/roomspaces/code/:code", roomspaceHandler.SearchRoomspaceByCode)
		protected.POST("/roomspaces/code/:code/join", roomspaceHandler.JoinRoomspaceByCode)
		protected.DELETE("/roomspaces/:id/members", middleware.ValidateRoomspaceMembership(), roomspaceHandler.RemoveMember)

		// Notification routes
		protected.GET("/notifications", notificationHandler.GetNotifications)
		protected.POST("/notifications/send-reminder", notificationHandler.SendPaymentReminder)
		protected.PUT("/notifications/:id/read", notificationHandler.MarkAsRead)
		protected.GET("/join-requests", notificationHandler.GetJoinRequests)
		protected.GET("/join-requests/pending", notificationHandler.GetPendingJoinRequest)
		protected.POST("/join-requests/:id/process", notificationHandler.ProcessJoinRequest)

		// Expense routes
		protected.POST("/expenses", expenseHandler.CreateExpense)
		protected.GET("/expenses", expenseHandler.GetExpenses)
		protected.GET("/expenses/:id", expenseHandler.GetExpenseByID)
		protected.PUT("/expenses/:id", expenseHandler.UpdateExpense)
		protected.DELETE("/expenses/:id", expenseHandler.DeleteExpense)
		protected.GET("/roomspaces/:id/expenses", middleware.ValidateRoomspaceMembership(), expenseHandler.GetRoomspaceExpenses)
		protected.GET("/roomspaces/:id/expenses/recent", middleware.ValidateRoomspaceMembership(), expenseHandler.GetRecentExpenses)
		
		// Expense Deletion Request routes
		protected.POST("/expenses/:id/deletion-request", expenseDeletionHandler.RequestExpenseDeletion)
		protected.POST("/deletion-requests/:id/respond", expenseDeletionHandler.RespondToDeletionRequest)
		protected.GET("/deletion-requests/pending", expenseDeletionHandler.GetPendingDeletionRequests)
		
		// Expense History routes
		protected.GET("/roomspaces/:id/history", middleware.ValidateRoomspaceMembership(), expenseHistoryHandler.GetRoomspaceHistory)
		protected.POST("/roomspaces/:id/history", middleware.ValidateRoomspaceMembership(), expenseHistoryHandler.CreateHistoryEntry)
		protected.GET("/roomspaces/:id/history/recent", middleware.ValidateRoomspaceMembership(), expenseHistoryHandler.GetRecentHistory)
		
		// Personal Expense routes
		protected.POST("/personal-expenses", expenseHandler.CreatePersonalExpense)
		protected.GET("/personal-expenses", expenseHandler.GetPersonalExpenses)
		protected.DELETE("/personal-expenses/:id", expenseHandler.DeletePersonalExpense)
		
		// Payment Notification routes
		protected.POST("/payment-notifications", paymentNotificationHandler.CreatePaymentNotification)
		protected.GET("/payment-notifications", paymentNotificationHandler.GetPaymentNotifications)
		protected.GET("/payment-notifications/:id", paymentNotificationHandler.GetPaymentNotification)
		protected.PUT("/payment-notifications/:id/processed", paymentNotificationHandler.MarkPaymentNotificationAsProcessed)
		protected.DELETE("/payment-notifications/:id", paymentNotificationHandler.DeletePaymentNotification)
		
		// Analytics routes
		protected.GET("/analytics/summary", analyticsHandler.GetSummary)
		protected.GET("/analytics/trends", analyticsHandler.GetTrends)
		protected.GET("/analytics/predictions", analyticsHandler.GetPredictions)
		protected.GET("/analytics/patterns", analyticsHandler.GetPatterns)
		protected.GET("/analytics/anomalies", analyticsHandler.GetAnomalies)
		protected.GET("/analytics/recommendations", analyticsHandler.GetRecommendations)
		protected.GET("/analytics/roomspace/:id", middleware.ValidateRoomspaceMembership(), analyticsHandler.GetRoomspaceAnalytics)
		protected.POST("/analytics/feedback", analyticsHandler.SubmitFeedback)
		
		// Balance routes
		protected.GET("/roomspaces/:id/balances", middleware.ValidateRoomspaceMembership(), balanceHandler.GetRoomspaceBalances)
		protected.GET("/roomspaces/:id/balances/:userId", middleware.ValidateRoomspaceMembership(), balanceHandler.GetUserBalance)
		protected.POST("/roomspaces/:id/settlements", middleware.ValidateRoomspaceMembership(), balanceHandler.CreateSettlement)
		protected.GET("/roomspaces/:id/settlements", middleware.ValidateRoomspaceMembership(), balanceHandler.GetSettlementHistory)
		protected.GET("/roomspaces/:id/settlements/suggestions", middleware.ValidateRoomspaceMembership(), balanceHandler.GetSettlementSuggestions)
		protected.POST("/roomspaces/:id/balances/refresh", middleware.ValidateRoomspaceMembership(), balanceHandler.RefreshBalanceCache)
		
		// Payment Confirmation routes
		protected.POST("/roomspaces/:id/payments/confirm", middleware.ValidateRoomspaceMembership(), paymentConfirmationHandler.CreatePaymentConfirmation)
		protected.PUT("/roomspaces/:id/payments/:paymentId/confirm", middleware.ValidateRoomspaceMembership(), paymentConfirmationHandler.ConfirmPayment)
		protected.PUT("/roomspaces/:id/payments/:paymentId/reject", middleware.ValidateRoomspaceMembership(), paymentConfirmationHandler.RejectPayment)
		protected.GET("/roomspaces/:id/payments/pending", middleware.ValidateRoomspaceMembership(), paymentConfirmationHandler.GetPendingConfirmations)
		protected.GET("/roomspaces/:id/payments/history", middleware.ValidateRoomspaceMembership(), paymentConfirmationHandler.GetPaymentHistory)
		protected.GET("/roomspaces/:id/payments/stats", middleware.ValidateRoomspaceMembership(), paymentConfirmationHandler.GetPaymentStats)
		
		// Recurring Expense routes
		protected.POST("/recurring-expenses", recurringExpenseHandler.CreateRecurringExpenseTemplate)
		protected.GET("/roomspaces/:id/recurring-expenses", middleware.ValidateRoomspaceMembership(), recurringExpenseHandler.GetRecurringExpenseTemplates)
		protected.PUT("/recurring-expenses/:template_id", recurringExpenseHandler.UpdateRecurringExpenseTemplate)
		protected.DELETE("/recurring-expenses/:template_id", recurringExpenseHandler.DeleteRecurringExpenseTemplate)
		protected.POST("/recurring-expenses/:template_id/restore", recurringExpenseHandler.RestoreRecurringExpenseTemplate)
		protected.GET("/recurring-expenses/notifications", recurringExpenseHandler.GetRecurringExpenseNotifications)
		protected.POST("/recurring-expenses/notifications/:notification_id/process", recurringExpenseHandler.ProcessRecurringExpenseNotification)
		protected.GET("/roomspaces/:id/recurring-expenses/upcoming", middleware.ValidateRoomspaceMembership(), recurringExpenseHandler.GetUpcomingRecurringExpenses)
		protected.GET("/roomspaces/:id/recurring-expenses/stats", middleware.ValidateRoomspaceMembership(), recurringExpenseHandler.GetRecurringExpenseStats)
		
		// eSewa Payment routes
		protected.POST("/payments/subscription/verify", esewaHandler.VerifySubscriptionPayment)
		protected.POST("/payments/settlement/verify", esewaHandler.VerifyBalanceSettlement)
		protected.GET("/payments/history", esewaHandler.GetPaymentHistory)
		protected.GET("/roomspaces/:id/settlements/history", middleware.ValidateRoomspaceMembership(), esewaHandler.GetSettlementHistory)
		
		// Stripe Payment routes
		protected.POST("/payment/stripe/create-intent", func(c *gin.Context) {
			handlers.CreatePaymentIntent(c.Writer, c.Request)
		})
		protected.POST("/payment/stripe/verify", func(c *gin.Context) {
			handlers.VerifyPaymentIntent(c.Writer, c.Request)
		})
		protected.POST("/payment/stripe/subscription/verify", func(c *gin.Context) {
			handlers.VerifySubscriptionPayment(c.Writer, c.Request)
		})
		
		// Subscription routes
		protected.GET("/subscription/current", subscriptionHandler.GetCurrentSubscription)
		protected.POST("/subscription/cancel", subscriptionHandler.CancelSubscription)
		protected.POST("/subscription/reactivate", subscriptionHandler.ReactivateSubscription)
		protected.GET("/subscription/history", subscriptionHandler.GetSubscriptionHistory)
		
		// Admin routes (moved to public section above)
		// protected.GET("/admin/stats", adminHandler.GetSystemStats)
		// protected.GET("/admin/users", adminHandler.GetAllUsers)
		// protected.GET("/admin/users/:userId", adminHandler.GetUserDetails)
		// protected.POST("/admin/users/:userId/ban", adminHandler.BanUser)
		// protected.POST("/admin/users/:userId/unban", adminHandler.UnbanUser)
		// protected.GET("/admin/users/:userId/ban-status", adminHandler.CheckUserBanStatus)
	}

	// Start server
	log.Printf("✅ Server starting on port %s", cfg.Port)
	if err := router.Run(":" + cfg.Port); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
