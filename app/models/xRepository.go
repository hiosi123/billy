package models

import (
	"database/sql"

	"github.com/jmoiron/sqlx"
)

type Repository interface {

	// building
	AllBuildings() ([]*Building, error)
	GetBuildingById(id int) (*Building, error)
	GetBuildingsByUserId(userId int) ([]*Building, error)
	CreateBuilding(building *Building) (*Building, error)
	UpdateBuildingById(building *Building) error
	DeleteBuildingById(id int) error

	// floor
	AllFloors() ([]*Floor, error)
	GetFloorById(id int) (*Floor, error)
	CreateFloor(floor *Floor) (*Floor, error)
	UpdateFloorById(floor *Floor) error
	DeleteFloorById(id int) error
	GetFloorsByBuildingId(buildingId int) ([]*Floor, error)

	// room
	AllRooms() ([]*Room, error)
	GetRoomById(id int) (*Room, error)
	CreateRoom(room *Room) (*Room, error)
	UpdateRoomById(room *Room) error
	DeleteRoomById(id int) error
	GetRoomsByBuildingId(buildingId int) ([]*Room, error)
	GetRoomsByFloorId(floorId int) ([]*Room, error)

	// bill
	AllBills() ([]*Bill, error)
	GetBillById(id int) (*Bill, error)
	GetBillByMonth(month string, buildingId int) ([]*Bill, error)
	CreateBill(bill *Bill) (*Bill, error)
	UpdateBillById(bill *Bill) error
	DeleteBillById(id int) error
	GetBillsByCondition(month string, roomId, floorId, buildingId int) ([]*BillInfo, error)

	// billHistory
	AllBillHistories() ([]*BillHistory, error)
	GetBillHistoryById(id int) (*BillHistory, error)
	CreateBillHistory(billHistory *BillHistory) (*BillHistory, error)
	UpdateBillHistoryById(billHistory *BillHistory) error
	DeleteBillHistoryById(id int) error
	GetBillHistoryByChargeMonth(month string, buildingId int) ([]*BillHistory, error)

	// buildingFee
	AllBuildingFees() ([]*BuildingFee, error)
	GetBuildingFeeById(id int) (*BuildingFee, error)
	CreateBuildingFee(buildingFee *BuildingFee) (*BuildingFee, error)
	UpdateBuildingFeeById(buildingFee *BuildingFee) error
	DeleteBuildingFeeById(id int) error
	GetBuildingFeeByBuildingId(buildingId int) (*BuildingFee, error)

	// user
	AllUsers() ([]*User, error)
	GetUserById(id int) (*User, error)
	GetUserByUsername(username string) (*User, error)
	CreateUser(user *User) (*User, error)
	UpdateUserById(user *User) error
	DeleteUserById(id int) error
}

type mysqlRepository struct {
	DB *sqlx.DB
}

func newMysqlRepository(conn *sql.DB) Repository {

	c := sqlx.NewDb(conn, "mysql")
	return &mysqlRepository{
		DB: c,
	}
}

type testRepository struct {
	DB *sqlx.DB
}

func newTestRepository(conn *sql.DB) Repository {
	return &testRepository{
		DB: sqlx.NewDb(conn, "mysql"),
	}
}
