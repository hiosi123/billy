package middleware

import (
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt"
	"github.com/tls1641/buiildingFee/app/config"
)

type JWTClaims struct {
	Sub   string `json:"sub"`
	Admin bool   `json:"admin"`
	jwt.StandardClaims
}

// GenerateJWT creates a new JWT token for the user
func GenerateJWT(userID int, isAdmin bool) (string, error) {
	userIDStr := strconv.Itoa(userID)

	claims := JWTClaims{
		Sub:   userIDStr,
		Admin: isAdmin,
		StandardClaims: jwt.StandardClaims{
			ExpiresAt: time.Now().Add(time.Hour * 24).Unix(), // Token expires in 24 hours
			IssuedAt:  time.Now().Unix(),
			NotBefore: time.Now().Unix(),
			Issuer:    "building-management-system",
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString([]byte(config.GetEnv().SECRET_KEY))
	if err != nil {
		return "", err
	}

	return tokenString, nil
}

func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		apiKeyHeader := c.GetHeader("X-API-Key")
		if apiKeyHeader == config.GetEnv().API_KEY {
			c.Set("auth_method", "API-Key")
			c.Next()
			return
		}

		// Second check: JWT in cookie
		tokenCookie, err := c.Cookie("accessToken")
		if err == nil && tokenCookie != "" {
			if validateAndSetUser(c, tokenCookie) {
				return
			}
		}

		// Third check: JWT in Authorization header
		authHeader := c.GetHeader("Authorization")
		if authHeader != "" && strings.HasPrefix(authHeader, "Bearer ") {
			tokenString := strings.TrimPrefix(authHeader, "Bearer ")
			if validateAndSetUser(c, tokenString) {
				return
			}
		}

		// No valid authentication found
		c.JSON(http.StatusUnauthorized, gin.H{"message": "Unauthorized"})
		c.Abort()
	}
}

// Helper function to validate JWT and set user context
func validateAndSetUser(c *gin.Context, tokenString string) bool {
	claims := &JWTClaims{}
	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		return []byte(config.GetEnv().SECRET_KEY), nil
	})

	if err == nil && token.Valid && claims.ExpiresAt > time.Now().Unix() {
		c.Set("auth_method", "JWT")
		c.Set("user_id", claims.Sub) // Store user ID for use in handlers
		c.Set("is_admin", claims.Admin)
		c.Next()
		return true
	}
	return false
}

// ExtractUserFromJWT extracts user information from JWT token
func ExtractUserFromJWT(c *gin.Context) (string, bool) {
	// Check for JWT in cookie first
	tokenCookie, err := c.Cookie("accessToken")
	if err == nil && tokenCookie != "" {
		user, isAdmin := parseJWT(tokenCookie)
		if user != "" {
			return user, isAdmin
		}
	}

	// Fallback to authorization header if cookie not present or invalid
	authHeader := c.GetHeader("Authorization")
	if authHeader != "" && strings.HasPrefix(authHeader, "Bearer ") {
		tokenString := strings.TrimPrefix(authHeader, "Bearer ")
		user, isAdmin := parseJWT(tokenString)
		if user != "" {
			return user, isAdmin
		}
	}

	return "", false
}

func parseJWT(tokenString string) (string, bool) {
	claims := &JWTClaims{}

	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		return []byte(config.GetEnv().SECRET_KEY), nil
	})

	if err == nil && token.Valid && claims.ExpiresAt > time.Now().Unix() {
		return claims.Sub, claims.Admin
	}

	return "", false
}

// Helper function to get user info from Gin context
func GetUserFromContext(c *gin.Context) (userID int, isAdmin bool, err error) {
	userIDStr, exists := c.Get("user_id")
	if !exists {
		return 0, false, fmt.Errorf("user not found in context")
	}

	// Convert user ID to int
	userID, err = strconv.Atoi(userIDStr.(string))
	if err != nil {
		return 0, false, fmt.Errorf("invalid user ID format")
	}

	isAdminVal, _ := c.Get("is_admin")
	isAdmin, _ = isAdminVal.(bool)

	return userID, isAdmin, nil
}
