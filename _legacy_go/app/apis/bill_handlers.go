package apis

import (
	"fmt"
	"log"
	"math"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/tls1641/buiildingFee/app/models"
	"github.com/tls1641/buiildingFee/app/util"
	"github.com/xuri/excelize/v2"
)

func (h *Handlers) GetBills(c *gin.Context) {
	b, err := h.app.Models.Bill.All()
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to get bills"})
		return
	}
	c.JSON(200, gin.H{"message": "Get bills", "data": b})
}

func (h *Handlers) GetBillById(c *gin.Context) {
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

	b, err := h.app.Models.Bill.Get(idInt)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to get bill by id"})
		return
	}

	c.JSON(200, gin.H{"message": "Get bill by id", "data": b})
}

func (h *Handlers) CreateBill(c *gin.Context) {
	var bill models.Bill
	if err := c.ShouldBindJSON(&bill); err != nil {
		c.JSON(400, gin.H{"error": "Invalid input"})
		return
	}

	b, err := h.app.Models.Bill.Create(&bill)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to create bill"})
		return
	}

	c.JSON(201, gin.H{"message": "Bill created", "data": b})
}

func (h *Handlers) UpdateBill(c *gin.Context) {
	var bill models.Bill
	if err := c.ShouldBindJSON(&bill); err != nil {
		c.JSON(400, gin.H{"error": "Invalid input"})
		return
	}

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

	bill.BillId = idInt
	err = h.app.Models.Bill.Update(&bill)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to update bill"})
		return
	}

	c.JSON(200, gin.H{"message": "Bill updated", "data": bill})
}

func (h *Handlers) DeleteBill(c *gin.Context) {
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
	err = h.app.Models.Bill.Delete(idInt)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to delete bill"})
		return
	}
	c.JSON(200, gin.H{"message": "Bill deleted"})
}

func (h *Handlers) InsertMeasure(c *gin.Context) {
	var usage Usage
	if err := c.ShouldBindJSON(&usage); err != nil {
		c.JSON(400, gin.H{"error": "Invalid input"})
		return
	}

	thisMonth, err := time.Parse("200601", usage.ChargeMonth)
	if err != nil {
		c.JSON(400, gin.H{"error": "Invalid charge month format, expected YYYYMM"})
		return
	}

	// 1. 지난달 사용량 가져오기
	lastMonth := thisMonth.AddDate(0, -1, 0).Format("200601")
	lastMonthBills, err := h.app.Models.Bill.GetBillByMonth(lastMonth, usage.BuildingId)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to get last month bills"})
		return
	}

	// 2. 이번달 사용량 가져오기
	thisMonthBills, err := h.app.Models.Bill.GetBillByMonth(usage.ChargeMonth, usage.BuildingId)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to get this month bills"})
		return
	}

	// 🔥 FIX 1: 맵 키를 올바르게 설정 (RoomId로 매핑하는 것이 더 적절해 보임)
	var thisMonthBillsMap = make(map[int]*models.Bill)
	for i := range thisMonthBills { // 🔥 FIX 2: 인덱스 사용으로 포인터 문제 해결
		bill := thisMonthBills[i]
		thisMonthBillsMap[bill.RoomId] = bill // 🔥 FIX 3: RoomId를 키로 사용
	}

	// 2-1.
	rooms, err := h.app.Models.Room.GetRoomByBuildingId(usage.BuildingId)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to get room by buildingId"})
		return
	}

	// 2-2. 해당 건물의 방들 다 찾아오기
	var roomMulitplyMap = make(map[int]*models.Room)
	for i := range rooms {
		room := rooms[i]
		roomMulitplyMap[room.RoomId] = room
	}

	var newBill *models.Bill
	var matchFound bool

	// 🔥 FIX 4: 지난달 bill 중에서 매칭되는 것을 찾기
	for _, lmb := range lastMonthBills {
		if usage.BuildingId == lmb.BuildingId && usage.FloorId == lmb.FloorId && usage.RoomId == lmb.RoomId {

			matchFound = true

			multi, exist := roomMulitplyMap[usage.RoomId]
			if !exist {
				multi.MeasureMultiply = 1
			}

			// 3. 신규 청구서 생성
			bill := models.Bill{
				WaterMeasure:       usage.WaterMeasure,
				WaterUsage:         calculateDifference(lmb.WaterMeasure, usage.WaterMeasure, 1),
				ElectricityMeasure: usage.ElectricityMeasure,
				ElectricityUsage:   calculateDifference(lmb.ElectricityMeasure, usage.ElectricityMeasure, multi.MeasureMultiply),
				RoomId:             usage.RoomId,
				FloorId:            usage.FloorId,
				BuildingId:         usage.BuildingId,
				ChargeMonth:        usage.ChargeMonth,
			}

			if multi.StrictWater > 0 {
				bill.WaterUsage = multi.StrictWater
			}
			if multi.StrictElectricity > 0 {
				bill.ElectricityUsage = multi.StrictElectricity
			}

			// 기존 청구서 확인
			existBill, err := h.app.Models.Bill.GetBillsByCondition(usage.ChargeMonth, usage.RoomId, usage.FloorId, usage.BuildingId)
			if err != nil {
				c.JSON(500, gin.H{"error": err.Error()})
				return
			}

			if len(existBill) > 0 {
				bill.BillId = existBill[0].BillId
				// 기존 청구서 업데이트
				err := h.app.Models.Bill.Update(&bill)
				if err != nil {
					c.JSON(500, gin.H{"error": err.Error()})
					return
				}
				newBill = &bill
			} else {
				// 새로운 청구서 생성
				fmt.Println("새로운 청구서 생성", bill)
				newBill, err = h.app.Models.Bill.Create(&bill)
				if err != nil {
					c.JSON(500, gin.H{"error": err.Error()})
					return
				}
			}
			break // 🔥 FIX 5: 매칭되면 루프 종료
		}
	}

	// 🔥 FIX 6: 나머지 bill들 처리를 별도 루프로 분리
	for _, lmb := range lastMonthBills {
		// 현재 처리된 room은 제외
		if usage.BuildingId == lmb.BuildingId && usage.FloorId == lmb.FloorId && usage.RoomId == lmb.RoomId {
			continue
		}

		// 🔥 FIX 7: 키를 RoomId로 변경
		if thisMonthBill, exists := thisMonthBillsMap[lmb.RoomId]; exists {

			multi, exist := roomMulitplyMap[lmb.RoomId]
			if !exist {
				multi.MeasureMultiply = 1
			}

			// 🔥 FIX 8: ElectricityUsage 계산 수정 (ElectricityMeasure를 사용해야 함)
			thisMonthBill.WaterUsage = calculateDifference(lmb.WaterMeasure, thisMonthBill.WaterMeasure, 1)
			thisMonthBill.ElectricityUsage = calculateDifference(lmb.ElectricityMeasure, thisMonthBill.ElectricityMeasure, multi.MeasureMultiply)

			if multi.StrictWater > 0 {
				thisMonthBill.WaterUsage = multi.StrictWater
			}
			if multi.StrictElectricity > 0 {
				thisMonthBill.ElectricityUsage = multi.StrictElectricity
			}

			err := h.app.Models.Bill.Update(thisMonthBill)
			if err != nil {
				log.Printf("Error updating bill for room %d: %v", lmb.RoomId, err)
				// 🔥 FIX 9: 다른 bill 업데이트 실패가 전체를 실패시키지 않도록 함
				continue
			}
		}
	}

	// 🔥 FIX 10: 매칭되지 않은 경우 처리
	if !matchFound {
		c.JSON(404, gin.H{"error": "No matching bill found in last month"})
		return
	}

	c.JSON(201, gin.H{"message": "Bill created", "data": newBill})
}

func (h *Handlers) GetBillsByCondition(c *gin.Context) {
	month := c.Query("month")
	roomId, _ := strconv.Atoi(c.Query("RoomId"))
	floorId, _ := strconv.Atoi(c.Query("FloorId"))
	buildingId, _ := strconv.Atoi(c.Query("BuildingId"))

	billInfo, err := h.app.Models.Bill.GetBillsByCondition(month, roomId, floorId, buildingId)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to get bills by ids"})
		return
	}

	c.JSON(200, gin.H{"message": "Get bills by ids", "data": billInfo})
}

// 헬퍼 함수 - 맵의 키들을 가져오기
func getIntKeys(m map[int]*Bill) []int {
	keys := make([]int, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	return keys
}

// {
//     "BuildingId": 1,
//     "Month": "202507",
//     "ElectricityTotalCost": 4504824,
//     "WaterTotalCost": 829140,
//     "ElectricityTotalUsage": 22001,
//     "WaterTotalUsage": 272,
//     "WaterSupplyCost": 397120,
//     "WaterSewerCost": 532680
// }

func (h *Handlers) CalculateBill(c *gin.Context) {
	var req CalculateBillReq
	err := c.ShouldBindJSON(&req)
	if err != nil {
		c.JSON(400, gin.H{"error": "Invalid input"})
		return
	}

	costPerKWh := req.ElectricityTotalCost / req.ElectricityTotalUsage
	// costPerTon := req.WaterTotalCost / req.WaterTotalUsage

	bills, err := h.app.Models.Bill.GetBillByMonth(req.Month, req.BuildingId)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to get bills by month"})
		return
	}

	// 0.1 방 관련 맵
	var roomMap = make(map[int]models.Room) // roomId -> Room
	var roomNoMap = make(map[int]float64)   // roomNumber -> RoomSpace
	// 0.2 전체 평수
	var totalSpace float64
	rooms, err := h.app.Models.Room.GetRoomByBuildingId(req.BuildingId)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to get rooms by buildingId"})
		return
	}

	for _, room := range rooms {
		// roomId로 Room 객체 저장
		roomMap[room.RoomId] = *room

		// roomNumber로 RoomSpace 저장 (중복 방지)
		if _, exist := roomNoMap[room.RoomNumber]; !exist {
			roomNoMap[room.RoomNumber] = room.RoomSpace
			totalSpace += room.RoomSpace
			log.Printf("Added to roomNoMap: roomNumber=%d, roomSpace=%.2f", room.RoomNumber, room.RoomSpace)
		} else {
			log.Printf("WARNING: Duplicate roomNumber=%d found, skipping", room.RoomNumber)
		}
	}

	// 1. bill에 관련한 맵 - 포인터 맵으로 변경 (roomNumber 기준)
	var fBillsMap = make(map[int]*Bill)
	// 2. 전체 측정 전기료
	var totalElectrictyCommonCost float64
	// 3. 전체 측정 물 사용량
	var totalWaterUsage float64
	// 4. bill 관련 maㅔ
	var billMap = make(map[int]*models.Bill)

	for _, bill := range bills {
		// roomId로 room 정보를 찾고, 그 room의 roomNumber를 키로 사용
		room, roomExists := roomMap[bill.RoomId]
		if !roomExists {
			log.Printf("Warning: Room not found for RoomId %d", bill.RoomId)
			continue
		}

		roomNumber := room.RoomNumber

		if fBill, exist := fBillsMap[roomNumber]; exist {
			// 기존 항목이 있으면 직접 수정 가능 (포인터이므로)
			fBill.WaterUsage += bill.WaterUsage
			fBill.ElectricityUsage += bill.ElectricityUsage
			fBill.CalculateElectricityCost(bill.ElectricityUsage, costPerKWh)
			totalElectrictyCommonCost += fBill.ElectricityCost
			totalWaterUsage += bill.WaterUsage
		} else {
			// 새 항목 생성
			fb := &Bill{
				WaterUsage:       bill.WaterUsage,
				ElectricityUsage: bill.ElectricityUsage,
				BuildingId:       req.BuildingId,
			}
			fb.CalculateElectricityCost(bill.ElectricityUsage, costPerKWh)
			totalElectrictyCommonCost += fb.ElectricityCost
			totalWaterUsage += bill.WaterUsage

			// 맵에 포인터 저장 (roomNumber 기준)
			fBillsMap[roomNumber] = fb
			billMap[roomNumber] = bill
		}

		log.Printf("bill %+v -> roomNumber: %d", bill, roomNumber)
	}

	for roomNo, fBill := range fBillsMap {
		fBill.CalculateElectricityCost(fBill.ElectricityUsage, costPerKWh)
		totalCommonCost := fBill.CalculateTotalCommonCost(req.ElectricityTotalCost, totalElectrictyCommonCost)
		log.Println("totalCommonCost", totalCommonCost)

		roomSpace, exists := roomNoMap[roomNo]
		if !exists {
			log.Printf("ERROR: roomSpace not found for roomNumber %d", roomNo)
			roomSpace = 0 // 기본값 설정
		}
		log.Printf("Room %d: space=%.2f, totalSpace=%.2f, exists=%v", roomNo, roomSpace, totalSpace, exists)

		fBill.CalculateElectricityCommonCost(totalCommonCost, roomSpace, totalSpace)

		fBill.CalculateElectricityTax()
		fBill.CalculateElectricityFund()
		fBill.CalculateWaterCostSupply(req.WaterSupplyCost, totalWaterUsage, fBill.WaterUsage)
		fBill.CalculateWaterCostSewer(req.WaterSewerCost, totalWaterUsage, fBill.WaterUsage)
		commonWaterCost := fBill.CalculateWaterCostCommon(req.WaterTotalCost, req.WaterSupplyCost, req.WaterSewerCost)
		log.Println("waterCommonCost: ", commonWaterCost)
		fBill.CalculateWaterCommonCost(commonWaterCost, totalWaterUsage, fBill.WaterUsage)
		fBill.CalculateTotal(2500)

		// 모든 금액 필드를 반올림
		fBill.ElectricityCost = math.Round(fBill.ElectricityCost)
		fBill.ElectricityCostCommon = math.Round(fBill.ElectricityCostCommon)
		fBill.ElectricityCostTax = math.Round(fBill.ElectricityCostTax)
		fBill.ElectricityCostFund = math.Round(fBill.ElectricityCostFund)
		fBill.ElectricityCostTotal = math.Round(fBill.ElectricityCostTotal)
		fBill.WaterCostSupply = math.Round(fBill.WaterCostSupply)
		fBill.WaterCostSewer = math.Round(fBill.WaterCostSewer)
		fBill.WaterCostCommon = math.Round(fBill.WaterCostCommon)
		fBill.WaterCostTotal = math.Round(fBill.WaterCostTotal)
		fBill.TotalCost = math.Round(fBill.TotalCost)

		seperateBill := billMap[roomNo]
		seperateBill.ElectricityBill = fBill.ElectricityCostTotal
		seperateBill.WaterBill = fBill.WaterCostTotal

		err := h.app.Models.Bill.Update(seperateBill)
		if err != nil {
			log.Println("failed to create bill")
		}

	}

	c.JSON(201, gin.H{"message": "Bill created", "data": fBillsMap})
}

func (h *Handlers) MakeBillExcel(c *gin.Context) {
	var bills []Bill
	err := c.ShouldBindJSON(&bills)
	if err != nil {
		c.JSON(400, gin.H{"error": "Invalid input"})
		return
	}

	// 1. 건물 id 로 모든 방 정보를 가져오기
	rooms, err := h.app.Models.Room.GetRoomByBuildingId(bills[0].BuildingId)
	if err != nil {
		c.JSON(500, gin.H{"error": "Failed to get building by buildingId"})
		return
	}

	// 2. 방 정보 맵에 저장
	var totalSpace float64
	var roomNumberMap = make(map[int]*models.Room)
	for _, room := range rooms {
		_, exist := roomNumberMap[room.RoomNumber]
		if !exist {
			roomNumberMap[room.RoomNumber] = room
			totalSpace += room.RoomSpace
		}
	}

	// 3. 건물 관리비 정보 가져오기
	buildingFee, err := h.app.Models.BuildingFee.GetBuildingFeeByBuildingId(bills[0].BuildingId)
	if err != nil {
		log.Println(err)
		c.JSON(500, gin.H{"error": "Failed to get buildingFee by buildingId"})
		return
	}

	// 4. 엑셀 파일 불러오기
	f, err := excelize.OpenFile("./excel/bill.xlsx")
	if err != nil {
		fmt.Printf("Error opening file: %v\n", err)
		c.JSON(500, gin.H{"error": "Failed to get excel file"})
		return
	}

	// 5. 명세서 정보 읽어서 엑셀 만들기
	for _, bill := range bills {
		room, exist := roomNumberMap[bill.RoomNumber]
		if exist {
			sourceSheetIndex, err := f.GetSheetIndex("bill")
			if err != nil {
				fmt.Println("failed to get sheet bill")
				c.JSON(500, gin.H{"error": "failed to get sheet bill"})
				return
			}

			GeneralManagementFee := buildingFee.GeneralManagementFee * room.RoomSpace / totalSpace
			PublicInspectionFee := buildingFee.PublicInspectionFee * room.RoomSpace / totalSpace
			FireManagementFee := buildingFee.FireManagementFee * room.RoomSpace / totalSpace
			ElevatorMaintenanceFee := buildingFee.ElevatorMaintenanceFee * room.RoomSpace / totalSpace
			SepticTankManagementFee := buildingFee.SepticTankManagementFee * room.RoomSpace / totalSpace
			ElectricalManagementFee := buildingFee.ElectricalManagementFee * room.RoomSpace / totalSpace
			ParkingManagementFee := buildingFee.ParkingManagementFee * room.RoomSpace / totalSpace

			var totalFee float64
			var fireInsuranceFee float64
			var totalFeeWI = GeneralManagementFee + PublicInspectionFee + FireManagementFee + ElevatorMaintenanceFee + SepticTankManagementFee + ElectricalManagementFee + ParkingManagementFee

			fireInsuranceFee = room.RoomBaseCost
			totalFee = totalFeeWI + room.RoomBaseCost

			var lateFee = totalFee * 0.02
			var totalLateFee = totalFee + lateFee
			var ElectricityLateCost = bill.ElectricityCostTotal * 0.02
			var WaterLateCost = bill.WaterCostTotal * 0.02
			var TotalLateCost = ElectricityLateCost + WaterLateCost + bill.TotalCost

			// 원본 시트의 설정들을 미리 저장
			originalPageLayout, _ := f.GetPageLayout("bill")
			originalSheetView, _ := f.GetSheetView("bill", 0)
			originalSheetProps, _ := f.GetSheetProps("bill")

			destSheetIndex, err := f.NewSheet(room.RoomName)
			if err != nil {
				fmt.Printf("Error creating new sheet: %v\n", err)
				c.JSON(500, gin.H{"error": "failed to get create new sheet"})
				return
			}

			err = f.CopySheet(sourceSheetIndex, destSheetIndex)
			if err != nil {
				fmt.Printf("Error Copying sheet: %v\n", err)
				c.JSON(500, gin.H{"error": "failed to copy sheet"})
				return
			}

			f.SetActiveSheet(destSheetIndex)

			// 원본 설정들을 다시 적용
			if originalPageLayout.Orientation != nil || originalPageLayout.Size != nil {
				f.SetPageLayout(room.RoomName, &originalPageLayout)
			}

			if originalSheetView.ZoomScale != nil {
				f.SetSheetView(room.RoomName, 0, &originalSheetView)
			}

			if originalSheetProps.FitToPage != nil {
				f.SetSheetProps(room.RoomName, &originalSheetProps)
			}

			// ===== A4 맞춤, 여백 설정 및 행/열 크기 조정 =====

			// 페이지 여백 최소화
			err = f.SetPageMargins(room.RoomName, &excelize.PageLayoutMarginsOptions{
				Top:    util.Float64Ptr(0.3),
				Bottom: util.Float64Ptr(0.3),
				Left:   util.Float64Ptr(0.25),
				Right:  util.Float64Ptr(0.25),
				Header: util.Float64Ptr(0.2),
				Footer: util.Float64Ptr(0.2),
			})
			if err != nil {
				fmt.Printf("Error setting margins: %v\n", err)
			}

			// A4 용지에 딱 맞게 설정
			f.SetPageLayout(room.RoomName, &excelize.PageLayoutOptions{
				Orientation:   util.StrPtr("landscape"),
				Size:          util.IntPtr(9),
				FitToWidth:    util.IntPtr(1),
				FitToHeight:   util.IntPtr(1),
				BlackAndWhite: util.BoolPtr(false),
			})

			// 행 높이 미세하게 증가 (1.1배)
			rows, _ := f.GetRows(room.RoomName)
			for i := 1; i <= len(rows); i++ {
				height, err := f.GetRowHeight(room.RoomName, i)
				if err == nil && height > 0 {
					f.SetRowHeight(room.RoomName, i, height*1.1)
				}
			}

			// 열 너비 미세하게 증가 (1.1배)
			cols, _ := f.GetCols(room.RoomName)
			for i := 0; i < len(cols); i++ {
				colName, _ := excelize.ColumnNumberToName(i + 1)
				width, err := f.GetColWidth(room.RoomName, colName)
				if err == nil && width > 0 {
					f.SetColWidth(room.RoomName, colName, colName, width*1.1)
				}
			}

			// ===== 설정 끝 =====

			f.SetSheetView(room.RoomName, 0, &excelize.ViewOptions{
				ZoomScale:   util.Float64Ptr(100),
				TopLeftCell: util.StrPtr("A1"),
				RightToLeft: util.BoolPtr(false),
			})

			//1. 년도, 월, 일자 찾아오기
			currentTime := time.Now()
			currentTimeStr := currentTime.Format("20060102")
			year := currentTimeStr[:4]
			month := currentTimeStr[4:6]
			date := currentTimeStr[6:]

			// 지난달 정보
			lastMonth := currentTime.AddDate(0, -1, 0)
			lastTimeStr := lastMonth.Format("20060102")
			lYear := lastTimeStr[:4]
			lMonth := lastTimeStr[4:6]
			fDate := "01"

			// 지난달 마지막일
			firstDayOfCurrentMonth := time.Date(currentTime.Year(), currentTime.Month(), 1, 0, 0, 0, 0, currentTime.Location())
			lastDayOfLastMonth := firstDayOfCurrentMonth.AddDate(0, 0, -1)
			lDate := fmt.Sprintf("%02d", lastDayOfLastMonth.Day())

			// 이번달 마지막일
			firstDayOfNextMonth := time.Date(currentTime.Year(), currentTime.Month()+1, 1, 0, 0, 0, 0, currentTime.Location())
			lastDayOfCurrentMonth := firstDayOfNextMonth.AddDate(0, 0, -1)
			tDate := fmt.Sprintf("%02d", lastDayOfCurrentMonth.Day())

			// 지지난달 정보
			lastlastMonth := currentTime.AddDate(0, -2, 0)
			lastlastTimeStr := lastlastMonth.Format("20060102")
			llYear := lastlastTimeStr[:4]
			llMonth := lastlastTimeStr[4:6]

			//2. 해당 시트 가져오기
			rows, err = f.GetRows(room.RoomName)
			if err != nil {
				fmt.Printf("Error reading rows: %v\n", err)
				return
			}

			//3. 플레이스홀더들을 실제 값으로 바꾸기
			for rowIndex, row := range rows {
				for colIndex, cellValue := range row {
					// 현재 날짜 관련
					if strings.Contains(cellValue, "(year)") {
						cellValue = strings.ReplaceAll(cellValue, "(year)", year)
					}
					if strings.Contains(cellValue, "(month)") {
						cellValue = strings.ReplaceAll(cellValue, "(month)", month)
					}
					if strings.Contains(cellValue, "(date)") {
						cellValue = strings.ReplaceAll(cellValue, "(date)", date)
					}

					// 지난달 관련
					if strings.Contains(cellValue, "(lYear)") {
						cellValue = strings.ReplaceAll(cellValue, "(lYear)", lYear)
					}
					if strings.Contains(cellValue, "(lMonth)") {
						cellValue = strings.ReplaceAll(cellValue, "(lMonth)", lMonth)
					}
					if strings.Contains(cellValue, "(fDate)") {
						cellValue = strings.ReplaceAll(cellValue, "(fDate)", fDate)
					}
					if strings.Contains(cellValue, "(lDate)") {
						cellValue = strings.ReplaceAll(cellValue, "(lDate)", lDate)
					}

					// 이번달 마지막일
					if strings.Contains(cellValue, "(tDate)") {
						cellValue = strings.ReplaceAll(cellValue, "(tDate)", tDate)
					}

					// 지지난달 관련
					if strings.Contains(cellValue, "(llYear)") {
						cellValue = strings.ReplaceAll(cellValue, "(llYear)", llYear)
					}
					if strings.Contains(cellValue, "(llMonth)") {
						cellValue = strings.ReplaceAll(cellValue, "(llMonth)", llMonth)
					}

					// 작업장 이름
					if strings.Contains(cellValue, "(name)") {
						cellValue = strings.ReplaceAll(cellValue, "(name)", room.RoomName)
					}

					space := strconv.FormatFloat(room.RoomSpace, 'f', 2, 64)
					// 작업장 면적
					if strings.Contains(cellValue, "(area)") {
						cellValue = strings.ReplaceAll(cellValue, "(area)", space)
					}

					// 전기료 관련
					if strings.Contains(cellValue, "(ElectricityCost)") {
						cellValue = strings.ReplaceAll(cellValue, "(ElectricityCost)", formatKoreanMoney(bill.ElectricityCost))
					}
					if strings.Contains(cellValue, "(ElectricityCostCommon)") {
						cellValue = strings.ReplaceAll(cellValue, "(ElectricityCostCommon)", formatKoreanMoney(bill.ElectricityCostCommon))
					}
					if strings.Contains(cellValue, "(ElectricityCostTax)") {
						cellValue = strings.ReplaceAll(cellValue, "(ElectricityCostTax)", formatKoreanMoney(bill.ElectricityCostTax))
					}
					if strings.Contains(cellValue, "(ElectricityCostFund)") {
						cellValue = strings.ReplaceAll(cellValue, "(ElectricityCostFund)", formatKoreanMoney(bill.ElectricityCostFund))
					}
					if strings.Contains(cellValue, "(ElectricityCostTotal)") {
						cellValue = strings.ReplaceAll(cellValue, "(ElectricityCostTotal)", formatKoreanMoney(bill.ElectricityCostTotal))
					}

					// 물 관련
					if strings.Contains(cellValue, "(WaterCostSupply)") {
						cellValue = strings.ReplaceAll(cellValue, "(WaterCostSupply)", formatKoreanMoney(bill.WaterCostSupply))
					}
					if strings.Contains(cellValue, "(WaterCostSewer)") {
						cellValue = strings.ReplaceAll(cellValue, "(WaterCostSewer)", formatKoreanMoney(bill.WaterCostSewer))
					}
					if strings.Contains(cellValue, "(WaterCostCommon)") {
						cellValue = strings.ReplaceAll(cellValue, "(WaterCostCommon)", formatKoreanMoney(bill.WaterCostCommon))
					}
					if strings.Contains(cellValue, "(WaterCostTotal)") {
						cellValue = strings.ReplaceAll(cellValue, "(WaterCostTotal)", formatKoreanMoney(bill.WaterCostTotal))
					}

					// 합계
					if strings.Contains(cellValue, "(TotalCost)") {
						cellValue = strings.ReplaceAll(cellValue, "(TotalCost)", formatKoreanMoney(bill.TotalCost))
					}

					// 관리비
					if strings.Contains(cellValue, "(GeneralManagementFee)") {
						cellValue = strings.ReplaceAll(cellValue, "(GeneralManagementFee)", formatKoreanMoney(GeneralManagementFee))
					}
					if strings.Contains(cellValue, "(PublicInspectionFee)") {
						cellValue = strings.ReplaceAll(cellValue, "(PublicInspectionFee)", formatKoreanMoney(PublicInspectionFee))
					}
					if strings.Contains(cellValue, "(FireManagementFee)") {
						cellValue = strings.ReplaceAll(cellValue, "(FireManagementFee)", formatKoreanMoney(FireManagementFee))
					}
					if strings.Contains(cellValue, "(ElevatorMaintenanceFee)") {
						cellValue = strings.ReplaceAll(cellValue, "(ElevatorMaintenanceFee)", formatKoreanMoney(ElevatorMaintenanceFee))
					}
					if strings.Contains(cellValue, "(SepticTankManagementFee)") {
						cellValue = strings.ReplaceAll(cellValue, "(SepticTankManagementFee)", formatKoreanMoney(SepticTankManagementFee))
					}
					if strings.Contains(cellValue, "(ElectricalManagementFee)") {
						cellValue = strings.ReplaceAll(cellValue, "(ElectricalManagementFee)", formatKoreanMoney(ElectricalManagementFee))
					}
					if strings.Contains(cellValue, "(ParkingManagementFee)") {
						cellValue = strings.ReplaceAll(cellValue, "(ParkingManagementFee)", formatKoreanMoney(ParkingManagementFee))
					}

					// 관리비 합산
					if strings.Contains(cellValue, "(totalFeeWI)") {
						cellValue = strings.ReplaceAll(cellValue, "(totalFeeWI)", formatKoreanMoney(totalFeeWI))
					}
					if strings.Contains(cellValue, "(fireInsuranceFee)") {
						cellValue = strings.ReplaceAll(cellValue, "(fireInsuranceFee)", formatKoreanMoney(fireInsuranceFee))
					}
					if strings.Contains(cellValue, "(totalFee)") {
						cellValue = strings.ReplaceAll(cellValue, "(totalFee)", formatKoreanMoney(totalFee))
					}

					// 늦은 돈
					if strings.Contains(cellValue, "(lateFee)") {
						cellValue = strings.ReplaceAll(cellValue, "(lateFee)", formatKoreanMoney(lateFee))
					}
					if strings.Contains(cellValue, "(totalLateFee)") {
						cellValue = strings.ReplaceAll(cellValue, "(totalLateFee)", formatKoreanMoney(totalLateFee))
					}

					// 물 전기
					if strings.Contains(cellValue, "(ElectricityLateCost)") {
						cellValue = strings.ReplaceAll(cellValue, "(ElectricityLateCost)", formatKoreanMoney(ElectricityLateCost))
					}
					if strings.Contains(cellValue, "(WaterLateCost)") {
						cellValue = strings.ReplaceAll(cellValue, "(WaterLateCost)", formatKoreanMoney(WaterLateCost))
					}
					if strings.Contains(cellValue, "(TotalLateCost)") {
						cellValue = strings.ReplaceAll(cellValue, "(TotalLateCost)", formatKoreanMoney(TotalLateCost))
					}

					// 변경된 값이 있으면 셀에 저장 (기존 스타일 유지)
					if cellValue != row[colIndex] {
						cellName, _ := excelize.CoordinatesToCellName(colIndex+1, rowIndex+1)
						f.SetCellValue(room.RoomName, cellName, cellValue)
					}
				}
			}

			if err := f.Save(); err != nil {
				fmt.Printf("Error saving file: %v\n", err)
				c.JSON(500, gin.H{"error": "failed to save sheet"})
				return
			}
		}
	}

	// Generate filename with timestamp
	currentTime := time.Now()
	filename := fmt.Sprintf("bills_%s.xlsx", currentTime.Format("20060102_150405"))
	filepath := fmt.Sprintf("./excel/%s", filename)

	// Save the file
	if err := f.SaveAs(filepath); err != nil {
		fmt.Printf("Error saving file: %v\n", err)
		c.JSON(500, gin.H{"error": "failed to save file"})
		return
	}

	defer f.Close()

	// Set headers for file download
	c.Header("Content-Description", "File Transfer")
	c.Header("Content-Transfer-Encoding", "binary")
	c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=%s", filename))
	c.Header("Content-Type", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")

	// Send the file
	c.File(filepath)

	// Optional: Clean up the temporary file after sending
	go func() {
		time.Sleep(1 * time.Second)
		os.Remove(filepath)
	}()
}

// 함수 맨 위에 헬퍼 함수 추가
func formatKoreanMoney(amount float64) string {
	// 1원 단위 절삭 (10원 단위로 반올림)
	truncatedAmount := math.Floor(amount/10) * 10

	// 정수로 변환
	intAmount := int64(truncatedAmount)
	str := fmt.Sprintf("%d", intAmount)

	// 천 단위마다 콤마 추가
	if len(str) <= 3 {
		return str
	}

	var result []string
	for i, digit := range str {
		if i > 0 && (len(str)-i)%3 == 0 {
			result = append(result, ",")
		}
		result = append(result, string(digit))
	}

	return strings.Join(result, "")
}

// [
//         {
//             "BillHistoryId": 8,
//             "RoomNumber": 101,
//             "ChargeMonth": "202507",
//             "ElectricityCost": 169128,
//             "ElectricityCostCommon": 55435,
//             "ElectricityCostTax": 22456,
//             "ElectricityCostFund": 6063,
//             "ElectricityCostTotal": 255583,
//             "WaterCostSupply": 5905,
//             "WaterCostSewer": 7921,
//             "WaterCostCommon": 584,
//             "WaterCostTotal": 14410,
//             "TotalCost": 269993,
//             "BuildingId": 1
//         },
//         {
//             "BillHistoryId": 9,
//             "RoomNumber": 102,
//             "ChargeMonth": "202507",
//             "ElectricityCost": 184894,
//             "ElectricityCostCommon": 23261,
//             "ElectricityCostTax": 20816,
//             "ElectricityCostFund": 5620,
//             "ElectricityCostTotal": 237091,
//             "WaterCostSupply": 1476,
//             "WaterCostSewer": 1980,
//             "WaterCostCommon": 146,
//             "WaterCostTotal": 3603,
//             "TotalCost": 240694,
//             "BuildingId": 1
//         },
//         {
//             "BillHistoryId": 10,
//             "RoomNumber": 401,
//             "ChargeMonth": "202507",
//             "ElectricityCost": 448210,
//             "ElectricityCostCommon": 240047,
//             "ElectricityCostTax": 68826,
//             "ElectricityCostFund": 18583,
//             "ElectricityCostTotal": 778166,
//             "WaterCostSupply": 38383,
//             "WaterCostSewer": 51486,
//             "WaterCostCommon": 3799,
//             "WaterCostTotal": 93668,
//             "TotalCost": 871833,
//             "BuildingId": 1
//         },
//         {
//             "BillHistoryId": 11,
//             "RoomNumber": 103,
//             "ChargeMonth": "202507",
//             "ElectricityCost": 776842,
//             "ElectricityCostCommon": 92224,
//             "ElectricityCostTax": 86907,
//             "ElectricityCostFund": 23465,
//             "ElectricityCostTotal": 981938,
//             "WaterCostSupply": 35431,
//             "WaterCostSewer": 47525,
//             "WaterCostCommon": 3506,
//             "WaterCostTotal": 86462,
//             "TotalCost": 1068400,
//             "BuildingId": 1
//         },
//         {
//             "BillHistoryId": 12,
//             "RoomNumber": 201,
//             "ChargeMonth": "202507",
//             "ElectricityCost": 520284,
//             "ElectricityCostCommon": 119447,
//             "ElectricityCostTax": 63973,
//             "ElectricityCostFund": 17273,
//             "ElectricityCostTotal": 723477,
//             "WaterCostSupply": 19192,
//             "WaterCostSewer": 25743,
//             "WaterCostCommon": 1899,
//             "WaterCostTotal": 46834,
//             "TotalCost": 770311,
//             "BuildingId": 1
//         },
//         {
//             "BillHistoryId": 13,
//             "RoomNumber": 301,
//             "ChargeMonth": "202507",
//             "ElectricityCost": 755752,
//             "ElectricityCostCommon": 182797,
//             "ElectricityCostTax": 93855,
//             "ElectricityCostFund": 25341,
//             "ElectricityCostTotal": 1060245,
//             "WaterCostSupply": 98911,
//             "WaterCostSewer": 132675,
//             "WaterCostCommon": 9788,
//             "WaterCostTotal": 241374,
//             "TotalCost": 1301619,
//             "BuildingId": 1
//         },
//         {
//             "BillHistoryId": 14,
//             "RoomNumber": 501,
//             "ChargeMonth": "202507",
//             "ElectricityCost": 753705,
//             "ElectricityCostCommon": 182797,
//             "ElectricityCostTax": 93650,
//             "ElectricityCostFund": 25286,
//             "ElectricityCostTotal": 1057937,
//             "WaterCostSupply": 197822,
//             "WaterCostSewer": 265350,
//             "WaterCostCommon": 19577,
//             "WaterCostTotal": 482749,
//             "TotalCost": 1540686,
//             "BuildingId": 1
//         }
// ]
