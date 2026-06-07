package middleware

import (
	"bytes"
	"fmt"
	"log"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/tls1641/buiildingFee/app/logging"
)

type CustomResponseWriter struct {
	gin.ResponseWriter
	body *bytes.Buffer
}

func (w *CustomResponseWriter) Write(b []byte) (int, error) {
	w.body.Write(b) // Store a copy of the response body
	return w.ResponseWriter.Write(b)
}

func (w *CustomResponseWriter) WriteString(s string) (int, error) {
	w.body.WriteString(s)
	return w.ResponseWriter.WriteString(s)
}

func Logger() gin.HandlerFunc {
	return func(c *gin.Context) {
		// startTime := time.Now()

		writer := &CustomResponseWriter{
			ResponseWriter: c.Writer,
			body:           bytes.NewBufferString(""),
		}
		c.Writer = writer

		// Extract user from JWT before processing request
		userFromJWT, isAdmin := ExtractUserFromJWT(c)

		// Store user info in context for handlers
		if userFromJWT != "" {
			c.Set("userId", userFromJWT)
			c.Set("isAdmin", isAdmin)
		}

		c.Next()

		// endTime := time.Now()
		// latency := endTime.Sub(startTime)

		statusCode := c.Writer.Status()
		responseBody := writer.body.String()

		orgID := c.GetHeader("orgId")
		if orgID == "" {
			orgID = "unknown"
		}
		user := c.GetHeader("user")
		if user == "" {
			if userFromJWT != "" {
				user = userFromJWT
			} else {
				user = "anonymous"
			}
		}

		if statusCode >= 500 {
			logging.LogAPI(
				logging.Error,
				orgID,
				c.Request.URL.Path,
				user,
				fmt.Sprintf("Error response: %v", responseBody),
			)

			// writeLog(c, statusCode, responseBody, latency)

		} else if statusCode >= 400 {
			logging.LogAPI(
				logging.Warn,
				orgID,
				c.Request.URL.Path,
				user,
				fmt.Sprintf("Client error response: %v", responseBody),
			)

			// writeLog(c, statusCode, responseBody, latency)

		} else {
			logging.LogAPI(
				logging.Info,
				orgID,
				c.Request.URL.Path,
				user,
				"Successful response",
			)
		}

	}
}

func writeLog(c *gin.Context, statusCode int, responseBody string, latency time.Duration) {
	log.Printf("Method: %s, Path: %s, Status: %d, Latency: %s, Response: %s",
		c.Request.Method,
		c.Request.URL.Path,
		statusCode,
		latency,
		responseBody,
	)
}
