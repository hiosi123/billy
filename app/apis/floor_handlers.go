package apis

import (
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/tls1641/buiildingFee/app/models"
)

func (h *Handlers) GetFloorById(c *gin.Context) {
	id := c.Param("id")
	if id == "" {
		c.JSON(400, gin.H{"error": "Floor ID is required"})
		return
	}
	idInt, err := strconv.Atoi(id)
	if err != nil {
		c.JSON(400, gin.H{"error": "Invalid floor ID"})
		return
	}

	f, err := h.app.Models.Floor.Get(idInt)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to get floor by id: " + err.Error()})
		return
	}

	c.JSON(200, gin.H{"message": "Get floor by id", "data": f})
}

func (h *Handlers) CreateFloor(c *gin.Context) {
	var floor models.Floor
	if err := c.ShouldBindJSON(&floor); err != nil {
		c.JSON(400, gin.H{"error": "Invalid input"})
		return
	}

	f, err := h.app.Models.Floor.Create(&floor)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to create floor: " + err.Error()})
		return
	}

	c.JSON(201, gin.H{"message": "Floor created", "data": f})
}

func (h *Handlers) UpdateFloor(c *gin.Context) {
	var floor models.Floor
	if err := c.ShouldBindJSON(&floor); err != nil {
		c.JSON(400, gin.H{"error": "Invalid input"})
		return
	}

	id := c.Param("id")
	if id == "" {
		c.JSON(400, gin.H{"error": "Floor ID is required"})
		return
	}
	idInt, err := strconv.Atoi(id)
	if err != nil {
		c.JSON(400, gin.H{"error": "Invalid floor ID"})
		return
	}

	floor.FloorId = idInt
	err = h.app.Models.Floor.Update(&floor)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to update floor: " + err.Error()})
		return
	}

	c.JSON(200, gin.H{"message": "Floor updated", "data": floor})
}

func (h *Handlers) DeleteFloor(c *gin.Context) {
	id := c.Param("id")
	if id == "" {
		c.JSON(400, gin.H{"error": "Floor ID is required"})
		return
	}
	idInt, err := strconv.Atoi(id)
	if err != nil {
		c.JSON(400, gin.H{"error": "Invalid floor ID"})
		return
	}
	err = h.app.Models.Floor.Delete(idInt)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to delete floor: " + err.Error()})
		return
	}
	c.JSON(200, gin.H{"message": "Floor deleted"})
}

func (h *Handlers) GetFloorsByBuildingId(c *gin.Context) {
	buildingId := c.Param("buildingId")
	if buildingId == "" {
		c.JSON(400, gin.H{"error": "Building ID is required"})
		return
	}
	buildingIdInt, err := strconv.Atoi(buildingId)
	if err != nil {
		c.JSON(400, gin.H{"error": "Invalid building ID"})
		return
	}

	floors, err := h.app.Models.Floor.GetFloorsByBuildingId(buildingIdInt)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to get floors by building ID: " + err.Error()})
		return
	}

	c.JSON(200, gin.H{"message": "Get floors by building ID", "data": floors})
}
