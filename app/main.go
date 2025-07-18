package main

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

type Response struct {
	Status  string `json:"status,omitempty"`
	Message string `json:"message,omitempty"`
	Version string `json:"version"`
}

func main() {
	version := "v1.0"

	// Initialize Gin router
	r := gin.Default()

	// Health check endpoint
	r.GET("/health", func(c *gin.Context) {
		response := Response{
			Status:  "healthy",
			Version: version,
		}
		c.JSON(http.StatusOK, response)
	})

	// Root endpoint
	r.GET("/", func(c *gin.Context) {
		response := Response{
			Message: "Hello from Blue/Green Demo with Gin!",
			Version: version,
		}
		c.JSON(http.StatusOK, response)
	})

	// Start server
	r.Run(":8080")
}
