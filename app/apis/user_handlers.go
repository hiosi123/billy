package apis

import (
	"crypto/sha256"
	"fmt"
	"log"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/tls1641/buiildingFee/app/middleware"
	"github.com/tls1641/buiildingFee/app/models"
)

func (h *Handlers) Login(c *gin.Context) {
	var loginData struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}
	if err := c.ShouldBindJSON(&loginData); err != nil {
		c.JSON(400, gin.H{"error": err.Error()})
		return
	}
	if loginData.Username == "" || loginData.Password == "" {
		c.JSON(400, gin.H{"error": "Username and Password are required"})
		return
	}
	user, err := h.app.Models.User.GetByUsername(loginData.Username)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	if user == nil {
		c.JSON(401, gin.H{"error": "Invalid username or password"})
		return
	}
	// Hash the provided password to compare with stored hash
	hasher := sha256.New() // Example using SHA-256
	_, err = hasher.Write([]byte(loginData.Password))
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to hash password"})
		return
	}
	hashedPassword := fmt.Sprintf("%x", hasher.Sum(nil))
	log.Println("Hashed Password:", hashedPassword) // Debugging line
	if user.Password != hashedPassword {
		c.JSON(401, gin.H{"error": "Invalid username or password"})
		return
	}

	// Generate JWT token
	token, err := middleware.GenerateJWT(user.UserId, user.Role == "admin")
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to generate token"})
		return
	}

	// Set cookie and return response
	c.SetCookie("accessToken", token, 3600*24, "/", "", false, true)
	c.JSON(200, gin.H{
		"message": "Login successful",
		"token":   token,
		"user": gin.H{
			"user_id":  user.UserId,
			"username": user.Username,
			"role":     user.Role,
		},
	})
}

// GetUserBuildings gets buildings owned by the current user
func (h *Handlers) GetUserBuildings(c *gin.Context) {
	userID, _, err := middleware.GetUserFromContext(c)
	if err != nil {
		c.JSON(401, gin.H{"error": "Unauthorized"})
		return
	}

	// Get buildings for this specific user
	buildings, err := h.app.Models.Building.GetByUserID(userID) // You'll need to implement this
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	c.JSON(200, gin.H{"buildings": buildings})
}

// GetCurrentUser gets the current user's profile
func (h *Handlers) GetCurrentUser(c *gin.Context) {
	userID, isAdmin, err := middleware.GetUserFromContext(c)
	if err != nil {
		c.JSON(401, gin.H{"error": "Unauthorized"})
		return
	}

	user, err := h.app.Models.User.Get(userID)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	c.JSON(200, gin.H{
		"user": gin.H{
			"user_id":  user.UserId,
			"username": user.Username,
			"role":     user.Role,
			"is_admin": isAdmin,
		},
	})
}

// Logout handler (optional)
func (h *Handlers) Logout(c *gin.Context) {
	// Clear the cookie
	c.SetCookie("accessToken", "", -1, "/", "", false, true)
	c.JSON(200, gin.H{"message": "Logged out successfully"})
}

// ChangePassword handler (optional)
// func (h *Handlers) ChangePassword(c *gin.Context) {
// 	userID, _, err := middleware.GetUserFromContext(c)
// 	if err != nil {
// 		c.JSON(401, gin.H{"error": "Unauthorized"})
// 		return
// 	}

// 	var changeData struct {
// 		CurrentPassword string `json:"current_password"`
// 		NewPassword     string `json:"new_password"`
// 	}

// 	if err := c.ShouldBindJSON(&changeData); err != nil {
// 		c.JSON(400, gin.H{"error": err.Error()})
// 		return
// 	}

// 	// Validate current password and update
// 	// Implementation depends on your User model methods
// 	err = h.app.Models.User.ChangePassword(userID, changeData.CurrentPassword, changeData.NewPassword)
// 	if err != nil {
// 		c.JSON(400, gin.H{"error": err.Error()})
// 		return
// 	}

// 	c.JSON(200, gin.H{"message": "Password changed successfully"})
// }

func (h *Handlers) GetUsers(c *gin.Context) {
	users, err := h.app.Models.User.All()
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	c.JSON(200, gin.H{"message": "Get all users", "data": users})
}

func (h *Handlers) GetUserByID(c *gin.Context) {
	id := c.Param("id")
	if id == "" {
		c.JSON(400, gin.H{"error": "Bill ID is required"})
		return
	}

	idInt, err := strconv.Atoi(id)
	if err != nil {
		c.JSON(400, gin.H{"error": "Invalid bill ID"})
		return
	}

	user, err := h.app.Models.User.Get(idInt)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	c.JSON(200, gin.H{"message": "Get user by ID", "data": user})
}

func (h *Handlers) GetUserByUsername(c *gin.Context) {
	username := c.Param("username")
	if username == "" {
		c.JSON(400, gin.H{"error": "Username is required"})
		return
	}
	user, err := h.app.Models.User.GetByUsername(username)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	c.JSON(200, gin.H{"message": "Get user by username", "data": user})
}

func (h *Handlers) CreateUser(c *gin.Context) {
	var user models.User
	if err := c.ShouldBindJSON(&user); err != nil {
		c.JSON(400, gin.H{"error": err.Error()})
		return
	}

	if user.Username == "" || user.Password == "" || user.Role == "" {
		c.JSON(400, gin.H{"error": "Username, Password, and Role are required"})
		return
	}

	if len(user.Username) < 5 || len(user.Password) < 10 {
		c.JSON(400, gin.H{"error": "Username must be at least 5 characters and Password at least 10 characters"})
		return
	}

	if strings.Contains(user.Password, " ") {
		c.JSON(400, gin.H{"error": "Password must not contain spaces"})
		return
	}

	// Hash the password before storing it
	hasher := sha256.New() // Example using SHA-256
	_, err := hasher.Write([]byte(user.Password))
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to hash password"})
		return
	}
	user.Password = fmt.Sprintf("%x", hasher.Sum(nil))

	u, err := h.app.Models.User.Create(&user)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	c.JSON(201, gin.H{"message": "User created successfully", "data": u})
}

func (h *Handlers) UpdateUser(c *gin.Context) {
	var user models.User
	if error := c.ShouldBindJSON(&user); error != nil {
		c.JSON(400, gin.H{"error": error.Error()})
		return
	}

	id := c.Param("id")
	if id == "" {
		c.JSON(400, gin.H{"error": "User ID is required"})
		return
	}

	idInt, err := strconv.Atoi(id)
	if err != nil {
		c.JSON(400, gin.H{"error": "Invalid user ID"})
		return
	}

	user.UserId = idInt
	err = h.app.Models.User.Update(&user)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}

	c.JSON(200, gin.H{"message": "User updated successfully", "data": user})

}

func (h *Handlers) DeleteUser(c *gin.Context) {
	id := c.Param("id")
	if id == "" {
		c.JSON(400, gin.H{"error": "User ID is required"})
		return
	}

	idInt, err := strconv.Atoi(id)
	if err != nil {
		c.JSON(400, gin.H{"error": "Invalid user ID"})
		return
	}

	err = h.app.Models.User.Delete(idInt)
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	c.JSON(200, gin.H{"message": "User deleted successfully"})
}
