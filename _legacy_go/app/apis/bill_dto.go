package apis

type Usage struct {
	BuildingId         int     `json:"BuildingId"`
	FloorId            int     `json:"FloorId"`
	RoomId             int     `json:"RoomId"`
	WaterMeasure       float64 `json:"WaterMeasure"`
	ElectricityMeasure float64 `json:"ElectricityMeasure"`
	ChargeMonth        string  `json:"ChargeMonth"` // Format: YYYYMM
}

type CalculateBillReq struct {
	BuildingId            int     // 건물id
	Month                 string  // YYYYMMDD
	ElectricityTotalCost  float64 // 전기세
	WaterTotalCost        float64 // 물세
	ElectricityTotalUsage float64 // 전체 전기 사용량
	WaterTotalUsage       float64 // 전체 물 사용량
	WaterSupplyCost       float64 // 상수도 량
	WaterSewerCost        float64 // 하수도 량
}
