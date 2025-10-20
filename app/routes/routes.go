package routes

import (
	"github.com/gin-gonic/gin"
	"github.com/tls1641/buiildingFee/app/apis"
	"github.com/tls1641/buiildingFee/app/middleware"
)

func BuildRouters(router *gin.Engine, handlers *apis.Handlers) {
	// 정적 파일 서빙 (CSS, JS, 이미지 등)
	router.Static("/static", "./frontend/static")

	// 특정 HTML 파일 서빙
	router.StaticFile("/", "./frontend/login.html")
	router.StaticFile("/settings", "./frontend/settings.html")
	router.StaticFile("/building", "./frontend/building.html")

	// 또는 프론트엔드 전체 폴더 서빙 (필요시)
	// router.Static("/frontend", "./frontend")

	auth := router.Group("/api/v1/auth")
	{
		auth.POST("/login", handlers.Login)
		auth.POST("/logout", handlers.Logout) // Logout (clears cookie)
	}

	api := router.Group("/api/v1", middleware.AuthMiddleware())
	{

		users := api.Group("/users")
		{
			users.GET("", handlers.GetUsers)
			users.GET("/:id", handlers.GetUserByID)
			users.GET("/username/:username", handlers.GetUserByUsername)
			users.POST("", handlers.CreateUser)
			users.PUT("/:id", handlers.UpdateUser)
			users.DELETE("/:id", handlers.DeleteUser)
		}

		buildings := api.Group("/buildings")
		{
			buildings.GET("", handlers.GetBuildings)
			buildings.GET("/:id", handlers.GetBuildingById)
			buildings.GET("/user", handlers.GetUserBuildings) // New endpoint to get buildings for the logged-in user
			buildings.POST("", handlers.CreateBuilding)
			buildings.PUT("/:id", handlers.UpdateBuilding)
			buildings.DELETE("/:id", handlers.DeleteBuilding)
		}

		bills := api.Group("/bills")
		{
			bills.GET("", handlers.GetBills)
			bills.GET("/:id", handlers.GetBillById)
			bills.POST("", handlers.CreateBill)
			bills.PUT("/:id", handlers.UpdateBill)
			bills.DELETE("/:id", handlers.DeleteBill)
			bills.POST("/measurements", handlers.InsertMeasure) // Usage Dto
			bills.GET("/conditions", handlers.GetBillsByCondition)
			bills.POST("/calculate", handlers.CalculateBill)
			bills.POST("/excel", handlers.MakeBillExcel)
		}

		floors := api.Group("/floors")
		{
			floors.GET("", handlers.GetFloors)
			floors.GET("/:id", handlers.GetFloorById)
			floors.POST("", handlers.CreateFloor)
			floors.PUT("/:id", handlers.UpdateFloor)
			floors.DELETE("/:id", handlers.DeleteFloor)
			floors.GET("/buildings/:buildingId", handlers.GetFloorsByBuildingId) // Get floors by building ID
		}

		rooms := api.Group("/rooms")
		{
			rooms.GET("", handlers.GetRooms)
			rooms.GET("/:id", handlers.GetRoomById)
			rooms.POST("", handlers.CreateRoom)
			rooms.PUT("/:id", handlers.UpdateRoom)
			rooms.DELETE("/:id", handlers.DeleteRoom)
			rooms.GET("/floors/:floorId", handlers.GetRoomsByFloorId)          // Get rooms by floor ID
			rooms.GET("/buildings/:buildingId", handlers.GetRoomsByBuildingId) // Get rooms by building ID
		}

		bill_histories := api.Group("/bills/histories")
		{
			bill_histories.GET("", handlers.GetBillHistories)
			bill_histories.GET("/:id", handlers.GetBillHistoryById)
			bill_histories.POST("", handlers.CreateBillHistory)
			bill_histories.PUT("/:id", handlers.UpdateBillHistory)
			bill_histories.DELETE("/:id", handlers.DeleteBillHistory)
			bill_histories.GET("/month/:month/building/:buildingId", handlers.GetBillHistoryByChargeMonth)
		}
	}
}
