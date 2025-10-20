package apis

import (
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/tls1641/buiildingFee/app/models"
)

func (h *Handlers) GetRooms(c *gin.Context) {
	r, err := h.app.Models.Room.All()
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to get rooms: " + err.Error()})
		return
	}

	c.JSON(200, gin.H{"message": "Get rooms", "data": r})
}

func (h *Handlers) GetRoomById(c *gin.Context) {
	id := c.Param("id")
	if id == "" {
		c.JSON(400, gin.H{"error": "Room ID is required"})
		return
	}
	idInt, err := strconv.Atoi(id)
	if err != nil {
		c.JSON(400, gin.H{"error": "Invalid room ID"})
		return
	}

	r, err := h.app.Models.Room.Get(idInt)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to get room by id: " + err.Error()})
		return
	}

	c.JSON(200, gin.H{"message": "Get room by id", "data": r})
}

func (h *Handlers) CreateRoom(c *gin.Context) {
	var room models.Room
	if err := c.ShouldBindJSON(&room); err != nil {
		c.JSON(400, gin.H{"error": "Invalid input"})
		return
	}

	r, err := h.app.Models.Room.Create(&room)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to create room: " + err.Error()})
		return
	}

	c.JSON(201, gin.H{"message": "Room created", "data": r})
}

func (h *Handlers) UpdateRoom(c *gin.Context) {
	var room models.Room
	if err := c.ShouldBindJSON(&room); err != nil {
		c.JSON(400, gin.H{"error": "Invalid input"})
		return
	}

	id := c.Param("id")
	if id == "" {
		c.JSON(400, gin.H{"error": "Room ID is required"})
		return
	}
	idInt, err := strconv.Atoi(id)
	if err != nil {
		c.JSON(400, gin.H{"error": "Invalid room ID"})
		return
	}

	room.RoomId = idInt
	err = h.app.Models.Room.Update(&room)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to update room: " + err.Error()})
		return
	}

	c.JSON(200, gin.H{"message": "Room updated", "data": room})
}

func (h *Handlers) DeleteRoom(c *gin.Context) {
	id := c.Param("id")
	if id == "" {
		c.JSON(400, gin.H{"error": "Room ID is required"})
		return
	}
	idInt, err := strconv.Atoi(id)
	if err != nil {
		c.JSON(400, gin.H{"error": "Invalid room ID"})
		return
	}
	err = h.app.Models.Room.Delete(idInt)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to delete room: " + err.Error()})
		return
	}
	c.JSON(200, gin.H{"message": "Room deleted"})
}

func (h *Handlers) GetRoomsByFloorId(c *gin.Context) {
	floorId := c.Param("floorId")
	if floorId == "" {
		c.JSON(400, gin.H{"error": "Floor ID is required"})
		return
	}
	floorIdInt, err := strconv.Atoi(floorId)
	if err != nil {
		c.JSON(400, gin.H{"error": "Invalid floor ID"})
		return
	}

	r, err := h.app.Models.Room.GetRoomsByFloorId(floorIdInt)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to get rooms by floor id: " + err.Error()})
		return
	}

	c.JSON(200, gin.H{"message": "Get rooms by floor id", "data": r})
}

func (h *Handlers) GetRoomsByBuildingId(c *gin.Context) {
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

	r, err := h.app.Models.Room.GetRoomByBuildingId(buildingIdInt)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to get rooms by building id: " + err.Error()})
		return
	}
	c.JSON(200, gin.H{"message": "Get rooms by building id", "data": r})
}
