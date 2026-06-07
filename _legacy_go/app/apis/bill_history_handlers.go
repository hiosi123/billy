package apis

import (
	"log"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/tls1641/buiildingFee/app/models"
)

func (h *Handlers) GetBillHistories(c *gin.Context) {
	b, err := h.app.Models.BillHistory.All()
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to get bill histories"})
		return
	}
	c.JSON(200, gin.H{"message": "Get bill histories", "data": b})
}

func (h *Handlers) GetBillHistoryById(c *gin.Context) {
	id := c.Param("id")
	if id == "" {
		c.JSON(400, gin.H{"error": "Bill History ID is required"})
		return
	}
	idInt, err := strconv.Atoi(id)
	if err != nil {
		c.JSON(400, gin.H{"error": "Invalid bill history ID"})
		return
	}

	b, err := h.app.Models.BillHistory.Get(idInt)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to get bill history by id"})
		return
	}

	c.JSON(200, gin.H{"message": "Get bill history by id", "data": b})
}

func (h *Handlers) CreateBillHistory(c *gin.Context) {
	var billHistory models.BillHistory
	if err := c.ShouldBindJSON(&billHistory); err != nil {
		c.JSON(400, gin.H{"error": "Invalid input"})
		return
	}

	bhs, err := h.app.Models.BillHistory.GetBillHistoryByChargeMonth(billHistory.ChargeMonth, billHistory.BuildingId)
	if err != nil {
		log.Printf("GetBillHistoryByChargeMonth: %v", err)
		c.JSON(500, gin.H{"error": "Failed to get bill history"})
		return
	}

	var updateComplete bool
	for _, bh := range bhs {
		if billHistory.ChargeMonth == bh.ChargeMonth && billHistory.RoomNumber == bh.RoomNumber {
			err = h.app.Models.BillHistory.Update(&billHistory)
			if err != nil {
				c.JSON(500, gin.H{"error": "Failed to update bill history"})
				return
			}
			updateComplete = true
		}
	}

	if !updateComplete {
		b, err := h.app.Models.BillHistory.Create(&billHistory)
		if err != nil {
			log.Printf("CreateBillHistory: %v", err)
			c.JSON(500, gin.H{"error": "Failed to create bill history"})
			return
		}
		c.JSON(201, gin.H{"message": "Bill History created", "data": b})
	}

	c.JSON(200, gin.H{"message": "Bill History updated"})

}

func (h *Handlers) UpdateBillHistory(c *gin.Context) {
	var billHistory models.BillHistory
	if err := c.ShouldBindJSON(&billHistory); err != nil {
		c.JSON(400, gin.H{"error": "Invalid input"})
		return
	}

	id := c.Param("id")
	if id == "" {
		c.JSON(400, gin.H{"error": "Bill History ID is required"})
		return
	}
	idInt, err := strconv.Atoi(id)
	if err != nil {
		c.JSON(400, gin.H{"error": "Invalid bill history ID"})
		return
	}

	billHistory.BillHistoryId = idInt
	err = h.app.Models.BillHistory.Update(&billHistory)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to update bill history"})
		return
	}

	c.JSON(200, gin.H{"message": "Bill History updated", "data": billHistory})
}

func (h *Handlers) DeleteBillHistory(c *gin.Context) {
	id := c.Param("id")
	if id == "" {
		c.JSON(400, gin.H{"error": "Bill History ID is required"})
		return
	}
	idInt, err := strconv.Atoi(id)
	if err != nil {
		c.JSON(400, gin.H{"error": "Invalid bill history ID"})
		return
	}
	err = h.app.Models.BillHistory.Delete(idInt)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to delete bill history"})
		return
	}
	c.JSON(200, gin.H{"message": "Bill History deleted"})
}

func (h *Handlers) GetBillHistoryByChargeMonth(c *gin.Context) {
	month := c.Param("month")
	if month == "" {
		c.JSON(400, gin.H{"error": "Charge month is required"})
		return
	}

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

	b, err := h.app.Models.BillHistory.GetBillHistoryByChargeMonth(month, buildingIdInt)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to get bill histories by charge month"})
		return
	}

	c.JSON(200, gin.H{"message": "Get bill histories by charge month", "data": b})
}
