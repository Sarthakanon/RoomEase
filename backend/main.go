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
	paymentNotificationHandler := handlers.NewPaymentNotificationHandler(dbService)
	healthHandler := handlers.NewHealthHandler()
	
	// Initialize analytics service and handler
	analyticsService := services.NewAnalyticsService(dbService)
	analyticsHandler := handlers.NewAnalyticsHandler(analyticsService, dbService)

	// Health check endpoint (public)
	router.GET("/health", healthHandler.Check)

	// Public routes
	router.POST("/api/auth/login", authHandler.Login)

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
		protected.GET("/roomspaces/code/:code", roomspaceHandler.SearchRoomspaceByCode)
		protected.POST("/roomspaces/code/:code/join", roomspaceHandler.JoinRoomspaceByCode)
		protected.DELETE("/roomspaces/:id/members", middleware.ValidateRoomspaceMembership(), roomspaceHandler.RemoveMember)

		// Notification routes
		protected.GET("/notifications", notificationHandler.GetNotifications)
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
	}

	// Start server
	log.Printf("✅ Server starting on port %s", cfg.Port)
	if err := router.Run(":" + cfg.Port); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
