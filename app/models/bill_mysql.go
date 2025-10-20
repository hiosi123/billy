package models

import (
	"context"
	"fmt"
	"time"
)

func (m *mysqlRepository) AllBills() ([]*Bill, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `SELECT bill_id, water_measure, water_usage, water_bill, electricity_measure, electricity_usage, electricity_bill, charge_month, room_id,floor_id, building_id FROM bills`

	var bills []*Bill
	err := m.DB.SelectContext(ctx, bills, query)
	if err != nil {
		return nil, fmt.Errorf("error getting bills: %w", err)
	}

	return bills, nil
}

func (m *mysqlRepository) GetBillById(id int) (*Bill, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `SELECT bill_id, water_measure, water_usage, water_bill, electricity_measure, electricity_usage, electricity_bill, charge_month, room_id, floor_id, building_id FROM bills WHERE bill_id = ?`

	var bill Bill
	err := m.DB.GetContext(ctx, &bill, query, id)
	if err != nil {
		return nil, fmt.Errorf("error getting bill by id: %w", err)
	}

	return &bill, nil
}

func (m *mysqlRepository) CreateBill(bill *Bill) (*Bill, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `INSERT INTO bills (water_measure, water_usage, water_bill, electricity_measure, electricity_usage, electricity_bill, charge_month, room_id, floor_id, building_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
	result, err := m.DB.ExecContext(ctx, query, bill.WaterMeasure, bill.WaterUsage, bill.WaterBill, bill.ElectricityMeasure, bill.ElectricityUsage, bill.ElectricityBill, bill.ChargeMonth, bill.RoomId, bill.FloorId, bill.BuildingId)
	if err != nil {
		return nil, fmt.Errorf("error creating bill: %w", err)
	}

	id, err := result.LastInsertId()
	if err != nil {
		return nil, fmt.Errorf("error getting last insert id: %w", err)
	}
	bill.BillId = int(id)

	return bill, nil
}

func (m *mysqlRepository) UpdateBillById(bill *Bill) error {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `UPDATE bills SET water_measure = ?, water_usage = ?, water_bill = ?, electricity_measure = ?, electricity_usage = ?, electricity_bill = ?, charge_month = ?, room_id = ?, floor_id = ?, building_id = ? WHERE bill_id = ?`
	_, err := m.DB.ExecContext(ctx, query, bill.WaterMeasure, bill.WaterUsage, bill.WaterBill, bill.ElectricityMeasure, bill.ElectricityUsage, bill.ElectricityBill, bill.ChargeMonth, bill.RoomId, bill.FloorId, bill.BuildingId, bill.BillId)
	if err != nil {
		return fmt.Errorf("error updating bill: %w", err)
	}

	return nil
}

func (m *mysqlRepository) DeleteBillById(id int) error {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `DELETE FROM bills WHERE bill_id = ?`
	_, err := m.DB.ExecContext(ctx, query, id)
	if err != nil {
		return fmt.Errorf("error deleting bill: %w", err)
	}

	return nil
}

func (m *mysqlRepository) GetBillByMonth(month string, buildingId int) ([]*Bill, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `SELECT bill_id, water_measure, water_usage, water_bill, electricity_measure, electricity_usage, electricity_bill, charge_month,room_id, floor_id, building_id FROM bills WHERE charge_month = ? AND building_id = ?`
	var bills []*Bill
	err := m.DB.SelectContext(ctx, &bills, query, month, buildingId)
	if err != nil {
		return nil, fmt.Errorf("error getting bill by month: %w", err)
	}

	return bills, nil
}

type BillInfo struct {
	BillId             int     `db:"bill_id"`
	WaterUsage         float64 `db:"water_usage"`
	WaterBill          float64 `db:"water_bill"`
	WaterMeasure       float64 `db:"water_measure"`
	ElectricityUsage   float64 `db:"electricity_usage"`
	ElectricityBill    float64 `db:"electricity_bill"`
	ElectricityMeasure float64 `db:"electricity_measure"`
	ChargeMonth        string  `db:"charge_month"` // Format: YYYYMM
	CreatedAt          string  `db:"created_at"`
	UpdatedAt          string  `db:"updated_at"`
	RoomId             int     `db:"room_id"`
	FloorId            int     `db:"floor_id"`
	BuildingId         int     `db:"building_id"`
	RoomNumber         int     `db:"room_number"`
	RoomName           string  `db:"room_name"`
	Floor              int     `db:"floor"`
}

func (m *mysqlRepository) GetBillsByCondition(month string, roomId, floorId, buildingId int) ([]*BillInfo, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `
	SELECT 
		b.bill_id, 
		b.water_usage, 
		b.water_bill, 
		b.water_measure,
		b.electricity_usage, 
		b.electricity_bill, 
		b.electricity_measure,
		b.charge_month, 
		b.room_id, 
		b.floor_id, 
		b.building_id,
		r.room_number,
		r.room_name,
		f.floor
	FROM bills b
	LEFT JOIN rooms r ON b.room_id = r.room_id
	LEFT JOIN floors f ON b.floor_id = f.floor_id
	WHERE 1=1
	`

	var args []any
	if month != "" {
		query += " AND b.charge_month = ?"
		args = append(args, month)
	}
	if roomId != 0 {
		query += " AND b.room_id = ?"
		args = append(args, roomId)
	}
	if floorId != 0 {
		query += " AND b.floor_id = ?"
		args = append(args, floorId)
	}
	if buildingId != 0 {
		query += " AND b.building_id = ?"
		args = append(args, buildingId)
	}

	var BF []*BillInfo
	err := m.DB.SelectContext(ctx, &BF, query, args...)
	if err != nil {
		return nil, fmt.Errorf("error getting bills by ids: %w", err)
	}

	return BF, nil
}
