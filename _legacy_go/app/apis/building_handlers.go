package apis

import (
	"log"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/tls1641/buiildingFee/app/models"
)

func (h *Handlers) GetBuildings(c *gin.Context) {
	b, err := h.app.Models.Building.All()
	if err != nil {
		log.Println("Failed to get buildings:", err)
		c.JSON(500, gin.H{"error": "Failed to get buildings"})
		return
	}

	c.JSON(200, gin.H{"message": "Get buildings", "data": b})
}

func (h *Handlers) GetBuildingById(c *gin.Context) {
	id := c.Param("id")
	if id == "" {
		c.JSON(400, gin.H{"error": "Building ID is required"})
		return
	}
	idInt, err := strconv.Atoi(id)
	if err != nil {
		c.JSON(400, gin.H{"error": "Invalid building ID"})
		return
	}

	b, err := h.app.Models.Building.Get(idInt)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to get building by id"})
		return
	}

	c.JSON(200, gin.H{"message": "Get building by id", "data": b})
}

func (h *Handlers) CreateBuilding(c *gin.Context) {
	var building models.Building
	if err := c.ShouldBindJSON(&building); err != nil {
		c.JSON(400, gin.H{"error": "Invalid input"})
		return
	}

	b, err := h.app.Models.Building.Create(&building)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to create building"})
		return
	}

	c.JSON(201, gin.H{"message": "Building created", "data": b})
}

func (h *Handlers) UpdateBuilding(c *gin.Context) {
	var building models.Building
	if err := c.ShouldBindJSON(&building); err != nil {
		c.JSON(400, gin.H{"error": "Invalid input"})
		return
	}

	id := c.Param("id")
	if id == "" {
		c.JSON(400, gin.H{"error": "Building ID is required"})
		return
	}
	idInt, err := strconv.Atoi(id)
	if err != nil {
		c.JSON(400, gin.H{"error": "Invalid building ID"})
		return
	}

	building.BuildingId = idInt
	err = h.app.Models.Building.Update(&building)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to update building"})
		return
	}

	c.JSON(200, gin.H{"message": "Building updated", "data": building})
}

func (h *Handlers) DeleteBuilding(c *gin.Context) {
	id := c.Param("id")
	if id == "" {
		c.JSON(400, gin.H{"error": "Building ID is required"})
		return
	}
	idInt, err := strconv.Atoi(id)
	if err != nil {
		c.JSON(400, gin.H{"error": "Invalid building ID"})
		return
	}
	err = h.app.Models.Building.Delete(idInt)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to delete building"})
		return
	}
	c.JSON(200, gin.H{"message": "Building deleted"})
}

func (h *Handlers) GetFloors(c *gin.Context) {
	f, err := h.app.Models.Floor.All()
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to get floors"})
		return
	}

	c.JSON(200, gin.H{"message": "Get floors", "data": f})
}
