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

		// Roomspace routes
		protected.GET("/roomspaces", roomspaceHandler.GetRoomspaces)
		protected.POST("/roomspaces", roomspaceHandler.CreateRoomspace)
		protected.GET("/roomspaces/:id", roomspaceHandler.GetRoomspace)
		protected.POST("/roomspaces/:id/join", roomspaceHandler.JoinRoomspace)
	}

	// Start server
	log.Printf("✅ Server starting on port %s", cfg.Port)
	if err := router.Run(":" + cfg.Port); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
