package models

import "database/sql"

var repo Repository

type Models struct {
	Building    Building
	Floor       Floor
	Room        Room
	Bill        Bill
	BillHistory BillHistory
	BuildingFee BuildingFee
	User        User
}

func New(conn *sql.DB, driverName string) *Models {
	if conn == nil {
		panic("database connection is nil")
	} else if driverName == "mysql" {
		repo = newMysqlRepository(conn)
	} else if driverName == "testDB" {
		repo = newTestRepository(conn)
	} else {
		panic("unsupported database driver")
	}

	return &Models{
		Building:    Building{},
		Floor:       Floor{},
		Room:        Room{},
		Bill:        Bill{},
		BillHistory: BillHistory{},
		User:        User{},
	}
}

type Building struct {
	BuildingId      int    `db:"building_id"`
	BuildingName    string `db:"building_name"`
	BuildingAddress string `db:"building_address"`
	BuildingFloors  int    `db:"building_floors"`
	Elevator        int    `db:"elevator"`
	Owner           string `db:"owner"`
	CreatedAt       string `db:"created_at"`
	UpdateAt        string `db:"updated_at"`
}

func (d *Building) All() ([]*Building, error) {
	return repo.AllBuildings()
}

func (d *Building) Get(id int) (*Building, error) {
	return repo.GetBuildingById(id)
}

func (d *Building) GetByUserID(userId int) ([]*Building, error) {
	return repo.GetBuildingsByUserId(userId)
}

func (d *Building) Create(building *Building) (*Building, error) {
	return repo.CreateBuilding(building)
}

func (d *Building) Update(building *Building) error {
	return repo.UpdateBuildingById(building)
}

func (d *Building) Delete(id int) error {
	return repo.DeleteBuildingById(id)
}

type Floor struct {
	FloorId    int     `db:"floor_id"`
	Floor      int     `db:"floor"`
	FloorSpace float64 `db:"floor_space"`
	CreatedAt  string  `db:"created_at"`
	UpdatedAt  string  `db:"updated_at"`
	BuildingId int     `db:"building_id"`
}

func (f *Floor) All() ([]*Floor, error) {
	return repo.AllFloors()
}

func (f *Floor) Get(id int) (*Floor, error) {
	return repo.GetFloorById(id)
}

func (f *Floor) Create(floor *Floor) (*Floor, error) {
	return repo.CreateFloor(floor)
}

func (f *Floor) Update(floor *Floor) error {
	return repo.UpdateFloorById(floor)
}

func (f *Floor) Delete(id int) error {
	return repo.DeleteFloorById(id)
}

func (f *Floor) GetFloorsByBuildingId(buildingId int) ([]*Floor, error) {
	return repo.GetFloorsByBuildingId(buildingId)
}

type Room struct {
	RoomId            int     `db:"room_id"`
	RoomNumber        int     `db:"room_number"`        // 호실
	RoomBaseCost      float64 `db:"room_base_cost"`     // 기본 요금
	MeasureMachine    string  `db:"measure_machine"`    // 계량기 명칭
	RoomName          string  `db:"room_name"`          // 호실 이름
	RoomSpace         float64 `db:"room_space"`         // 호실 면적
	StrictWater       float64 `db:"strict_water"`       // 고정 상수도 사용량
	StrictElectricity float64 `db:"strict_electricity"` // 고정 전기 사용량
	MeasureNo         int     `db:"measure_no"`         // 계량기 번호
	MeasureMultiply   float64 `db:"measure_multiply"`   // 계량기 배수
	CreatedAt         string  `db:"created_at"`
	UpdatedAt         string  `db:"updated_at"`
	FloorId           int     `db:"floor_id"`
	BuildingId        int     `db:"building_id"`

	Floor int `db:"floor"`
}

func (r *Room) All() ([]*Room, error) {
	return repo.AllRooms()
}

func (r *Room) Get(id int) (*Room, error) {
	return repo.GetRoomById(id)
}

func (r *Room) Create(room *Room) (*Room, error) {
	return repo.CreateRoom(room)
}

func (r *Room) Update(room *Room) error {
	return repo.UpdateRoomById(room)
}

func (r *Room) Delete(id int) error {
	return repo.DeleteRoomById(id)
}

func (r *Room) GetRoomByBuildingId(buildingId int) ([]*Room, error) {
	return repo.GetRoomsByBuildingId(buildingId)
}

func (r *Room) GetRoomsByFloorId(floorId int) ([]*Room, error) {
	return repo.GetRoomsByFloorId(floorId)
}

type Bill struct {
	BillId             int     `db:"bill_id"`
	WaterMeasure       float64 `db:"water_measure"`
	WaterUsage         float64 `db:"water_usage"`
	WaterBill          float64 `db:"water_bill"`
	ElectricityMeasure float64 `db:"electricity_measure"`
	ElectricityUsage   float64 `db:"electricity_usage"`
	ElectricityBill    float64 `db:"electricity_bill"`
	ChargeMonth        string  `db:"charge_month"` // Format: YYYYMM
	CreatedAt          string  `db:"created_at"`
	UpdatedAt          string  `db:"updated_at"`
	RoomId             int     `db:"room_id"`
	FloorId            int     `db:"floor_id"`
	BuildingId         int     `db:"building_id"`
}

func (b *Bill) All() ([]*Bill, error) {
	return repo.AllBills()
}

func (b *Bill) Get(id int) (*Bill, error) {
	return repo.GetBillById(id)
}

func (b *Bill) Create(bill *Bill) (*Bill, error) {
	return repo.CreateBill(bill)
}

func (b *Bill) Update(bill *Bill) error {
	return repo.UpdateBillById(bill)
}

func (b *Bill) Delete(id int) error {
	return repo.DeleteBillById(id)
}

// month YYYYMM
func (b *Bill) GetBillByMonth(month string, buildingId int) ([]*Bill, error) {
	return repo.GetBillByMonth(month, buildingId)
}

func (b *Bill) GetBillsByCondition(month string, roomId, floorId, buildingId int) ([]*BillInfo, error) {
	return repo.GetBillsByCondition(month, roomId, floorId, buildingId)
}

type BillHistory struct {
	BillHistoryId         int     `db:"bill_history_id"`
	RoomNumber            int     `db:"room_number"`
	ChargeMonth           string  `db:"charge_month"`
	ElectricityCost       float64 `db:"electricity_cost"`
	ElectricityCostCommon float64 `db:"electricity_cost_common"`
	ElectricityCostTax    float64 `db:"electricity_cost_tax"`
	ElectricityCostFund   float64 `db:"electricity_cost_fund"`
	ElectricityCostTotal  float64 `db:"electricity_cost_total"`
	WaterCostSupply       float64 `db:"water_cost_supply"`
	WaterCostSewer        float64 `db:"water_cost_sewer"`
	WaterCostCommon       float64 `db:"water_cost_common"`
	WaterCostTotal        float64 `db:"water_cost_total"`
	TotalCost             float64 `db:"total_cost"`
	BuildingId            int     `db:"building_id"`
}

func (b *BillHistory) All() ([]*BillHistory, error) {
	return repo.AllBillHistories()
}

func (b *BillHistory) Get(id int) (*BillHistory, error) {
	return repo.GetBillHistoryById(id)
}

func (b *BillHistory) Create(billHistory *BillHistory) (*BillHistory, error) {
	return repo.CreateBillHistory(billHistory)
}

func (b *BillHistory) Update(billHistory *BillHistory) error {
	return repo.UpdateBillHistoryById(billHistory)
}

func (b *BillHistory) Delete(id int) error {
	return repo.DeleteBillHistoryById(id)
}

func (b *BillHistory) GetBillHistoryByChargeMonth(month string, buildingId int) ([]*BillHistory, error) {
	return repo.GetBillHistoryByChargeMonth(month, buildingId)
}

type BuildingFee struct {
	BuildingId              int     `db:"building_id"`
	GeneralManagementFee    float64 `db:"general_management_fee"`
	PublicInspectionFee     float64 `db:"public_inspection_fee"`
	FireManagementFee       float64 `db:"fire_management_fee"`
	ElevatorMaintenanceFee  float64 `db:"elevator_maintenance_fee"`
	SepticTankManagementFee float64 `db:"septic_tank_management_fee"`
	ElectricalManagementFee float64 `db:"electrical_management_fee"`
	ParkingManagementFee    float64 `db:"parking_management_fee"`
}

func (bf *BuildingFee) All() ([]*BuildingFee, error) {
	return repo.AllBuildingFees()
}

func (bf *BuildingFee) Get(id int) (*BuildingFee, error) {
	return repo.GetBuildingFeeById(id)
}

func (bf *BuildingFee) Create(buildingFee *BuildingFee) (*BuildingFee, error) {
	return repo.CreateBuildingFee(buildingFee)
}

func (bf *BuildingFee) Update(buildingFee *BuildingFee) error {
	return repo.UpdateBuildingFeeById(buildingFee)
}

func (bf *BuildingFee) Delete(id int) error {
	return repo.DeleteBuildingFeeById(id)
}

func (bf *BuildingFee) GetBuildingFeeByBuildingId(buildingId int) (*BuildingFee, error) {
	return repo.GetBuildingFeeByBuildingId(buildingId)
}

type User struct {
	UserId    int    `db:"user_id"`
	Username  string `db:"username"`
	Password  string `db:"password"`
	Role      string `db:"role"`
	CreatedAt string `db:"created_at"`
	UpdatedAt string `db:"updated_at"`
}

func (u *User) All() ([]*User, error) {
	return repo.AllUsers()
}

func (u *User) Get(id int) (*User, error) {
	return repo.GetUserById(id)
}

func (u *User) GetByUsername(username string) (*User, error) {
	return repo.GetUserByUsername(username)
}

func (u *User) Create(user *User) (*User, error) {
	return repo.CreateUser(user)
}

func (u *User) Update(user *User) error {
	return repo.UpdateUserById(user)
}

func (u *User) Delete(id int) error {
	return repo.DeleteUserById(id)
}
