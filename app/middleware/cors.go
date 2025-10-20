package middleware

import (
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/tls1641/buiildingFee/app/config"
)

func CORS() gin.HandlerFunc {
	config := cors.Config{
		// Keep your existing allowed origins
		AllowOrigins: []string{
			config.GetEnv().CORS_1,
			config.GetEnv().CORS_2,
			config.GetEnv().CORS_3,
			config.GetEnv().CORS_4,
		},
		AllowMethods: []string{
			"GET",
			"POST",
			"PUT",
			"PATCH",
			"DELETE",
			"OPTIONS",
		},
		AllowCredentials: true,
		AllowHeaders: []string{
			"Authorization",
			"withCredentials",
			"Content-Type",
			"Accept",
			"Origin",
		},
		ExposeHeaders: []string{
			"Content-Length",
			"Content-Type",
		},
		MaxAge: 12 * time.Hour,
	}

	return cors.New(config)
}
