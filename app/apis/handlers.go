package apis

import (
	"math"

	apps "github.com/tls1641/buiildingFee/app"
)

type Handlers struct {
	app *apps.Application
}

func NewHandlers(app *apps.Application) *Handlers {
	return &Handlers{
		app: app,
	}
}

type Bill struct {
	ElectricityCost       float64 `json:"ElectricityCost"`
	ElectricityCostCommon float64 `json:"ElectricityCostCommon"`
	ElectricityCostTax    float64 `json:"ElectricityCostTax"`
	ElectricityCostFund   float64 `json:"ElectricityCostFund"`
	ElectricityCostTotal  float64 `json:"ElectricityCostTotal"`

	WaterCostSupply float64 `json:"WaterCostSupply"`
	WaterCostSewer  float64 `json:"WaterCostSewer"`
	WaterCostCommon float64 `json:"WaterCostCommon"`
	WaterCostTotal  float64 `json:"WaterCostTotal"`

	TotalCost float64 `json:"TotalCost"`

	WaterUsage       float64 `json:"-"`
	ElectricityUsage float64 `json:"-"`

	BuildingId int `json:"BuildingId"`
	RoomNumber int `json:"RoomNumber"`
}

// 전체 소계를 계산하는 메서드
func (b *Bill) CalculateTotal(tvCost float64) {
	b.ElectricityCostTotal = b.ElectricityCost + b.ElectricityCostCommon + b.ElectricityCostTax + b.ElectricityCostFund + tvCost
	b.WaterCostTotal = b.WaterCostSupply + b.WaterCostSewer + b.WaterCostCommon
	b.TotalCost = b.ElectricityCostTotal + b.WaterCostTotal
}

// 해당 방의 전기세를 계산하는 메서드
func (b *Bill) CalculateElectricityCost(electricityUsage float64, costPerKWh float64) {
	b.ElectricityCost = electricityUsage * costPerKWh
}

// 전체 공동 전기 요금을 계산하는 메서드
func (b *Bill) CalculateTotalCommonCost(electricityBill float64, totalElectricityCommonCost float64) float64 {
	return electricityBill - totalElectricityCommonCost
}

// 해당 방의 공동 전기 요금을 계산하는 메서드
func (b *Bill) CalculateElectricityCommonCost(totalCommonCost float64, roomSize float64, totalSize float64) {
	b.ElectricityCostCommon = (totalCommonCost * roomSize) / totalSize
}

// 해당 방의 부가가치세를 계산하는 메서드
func (b *Bill) CalculateElectricityTax() {
	b.ElectricityCostTax = (b.ElectricityCost + b.ElectricityCostCommon) * 0.1 // 10% VAT
}

// 해당 방의 전력 기금을 계산하는 메서드
func (b *Bill) CalculateElectricityFund() {
	b.ElectricityCostFund = (b.ElectricityCost + b.ElectricityCostCommon) * 0.027 // 2.7% fund
}

// 해당 방의 상수도 요금을 계산하는 메서드
func (b *Bill) CalculateWaterCostSupply(waterBill float64, totalWaterUsage float64, roomWaterusage float64) {
	b.WaterCostSupply = (waterBill * roomWaterusage) / totalWaterUsage
}

// 해당 방의 하수도 요금을 계산하는 메서드
func (b *Bill) CalculateWaterCostSewer(waterBill float64, totalWaterUsage float64, roomWaterusage float64) {
	b.WaterCostSewer = (waterBill * roomWaterusage) / totalWaterUsage
}

// 전체 공동 수도 요금을 계산하는 메서드
func (b *Bill) CalculateWaterCostCommon(waterBill float64, waterSupplyBill float64, waterSewerBill float64) float64 {
	commonWaterCost := waterBill - (waterSupplyBill + waterSewerBill)
	return commonWaterCost
}

// 해당 방의 공동 수도 요금을 계산하는 메서드
func (b *Bill) CalculateWaterCommonCost(totalCommonCost float64, totalWaterUsage float64, roomWaterUsage float64) {
	b.WaterCostCommon = (totalCommonCost * roomWaterUsage) / totalWaterUsage
}

// getNextPowerOf10 returns the next power of 10 greater than the integer part of the given number
func getNextPowerOf10(n float64) float64 {
	if n <= 0 {
		return 1
	}

	// Get the integer part of the number
	intPart := int(math.Floor(n))

	// Calculate the number of digits in the integer part
	digits := int(math.Floor(math.Log10(float64(intPart)))) + 1

	// Return 10^digits as float64
	return math.Pow(10, float64(digits))
}

// calculateDifference calculates the difference between two float64 numbers
// If the result would be negative, it uses the next power of 10 as rollover point
func calculateDifference(a, b, multi float64) float64 {
	a = a * multi
	b = b * multi

	diff := b - a
	if diff < 0 {
		// Find the larger number to determine rollover point
		larger := a
		if b > a {
			larger = b
		}

		// Get the next power of 10 as rollover point
		rolloverPoint := getNextPowerOf10(larger)

		return (rolloverPoint - a) + b
	}
	return diff
}
