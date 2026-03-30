package handler

import (
	"net/http"
	"roomease/backend/config"
	"roomease/backend/handlers"

	"github.com/gin-gonic/gin"
)

func Stats(w http.ResponseWriter, r *http.Request) {
	// Initialize configuration
	cfg := config.LoadConfig()
	config.InitFirebase(cfg.FirebaseCredentialPath)
	config.InitPostgreSQL(cfg.PostgresDatabaseURL)

	gin.SetMode(gin.ReleaseMode)
	router := gin.New()
	
	adminHandler := handlers.NewAdminHandler()
	
	router.GET("/", adminHandler.GetSystemStats)
	
	router.ServeHTTP(w, r)
}