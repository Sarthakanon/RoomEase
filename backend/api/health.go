package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

func Health(w http.ResponseWriter, r *http.Request) {
	gin.SetMode(gin.ReleaseMode)
	router := gin.New()
	
	router.GET("/", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"status":  "ok",
			"service": "RoomEase Backend",
			"message": "Backend is running successfully on Vercel!",
		})
	})
	
	router.ServeHTTP(w, r)
}