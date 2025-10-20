package models

import (
	"context"
	"fmt"
	"time"
)

func (m *mysqlRepository) AllBillHistories() ([]*BillHistory, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `
		SELECT 
			bill_history_id,
			room_number,
			charge_month,
			electricity_cost,
			electricity_cost_common,
			electricity_cost_tax,
			electricity_cost_fund,
			electricity_cost_total,
			water_cost_supply,
			water_cost_sewer,
			water_cost_common,
			water_cost_total,
			total_cost,
			building_id
		FROM bill_histories
	`

	var billHistories []*BillHistory
	err := m.DB.SelectContext(ctx, &billHistories, query)
	if err != nil {
		return nil, fmt.Errorf("error getting bill_histories: %w", err)
	}

	return billHistories, nil
}

func (m *mysqlRepository) GetBillHistoryById(id int) (*BillHistory, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `
		SELECT 
			bill_history_id,
			room_number,
			charge_month,
			electricity_cost,
			electricity_cost_common,
			electricity_cost_tax,
			electricity_cost_fund,
			electricity_cost_total,
			water_cost_supply,
			water_cost_sewer,
			water_cost_common,
			water_cost_total,
			total_cost,
			building_id
		FROM bill_histories
		WHERE bill_history_id = ?
	`

	var billHistory BillHistory
	err := m.DB.GetContext(ctx, &billHistory, query, id)
	if err != nil {
		return nil, fmt.Errorf("error getting bill_history by id: %w", err)
	}

	return &billHistory, nil
}

func (m *mysqlRepository) CreateBillHistory(billHistory *BillHistory) (*BillHistory, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `
		INSERT INTO bill_histories (
			room_number,
			charge_month,
			electricity_cost,
			electricity_cost_common,
			electricity_cost_tax,
			electricity_cost_fund,
			electricity_cost_total,
			water_cost_supply,
			water_cost_sewer,
			water_cost_common,
			water_cost_total,
			total_cost,
			building_id
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	`

	result, err := m.DB.ExecContext(ctx, query,
		billHistory.RoomNumber,
		billHistory.ChargeMonth,
		billHistory.ElectricityCost,
		billHistory.ElectricityCostCommon,
		billHistory.ElectricityCostTax,
		billHistory.ElectricityCostFund,
		billHistory.ElectricityCostTotal,
		billHistory.WaterCostSupply,
		billHistory.WaterCostSewer,
		billHistory.WaterCostCommon,
		billHistory.WaterCostTotal,
		billHistory.TotalCost,
		billHistory.BuildingId,
	)
	if err != nil {
		return nil, fmt.Errorf("error creating bill_history: %w", err)
	}

	id, err := result.LastInsertId()
	if err != nil {
		return nil, fmt.Errorf("error getting last insert id: %w", err)
	}
	billHistory.BillHistoryId = int(id)

	return billHistory, nil
}

func (m *mysqlRepository) UpdateBillHistoryById(billHistory *BillHistory) error {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `
		UPDATE bill_histories SET 
			room_number = ?,
			charge_month = ?,
			electricity_cost = ?,
			electricity_cost_common = ?,
			electricity_cost_tax = ?,
			electricity_cost_fund = ?,
			electricity_cost_total = ?,
			water_cost_supply = ?,
			water_cost_sewer = ?,
			water_cost_common = ?,
			water_cost_total = ?,
			total_cost = ?,
			building_id = ?
		WHERE bill_history_id = ?
	`

	_, err := m.DB.ExecContext(ctx, query,
		billHistory.RoomNumber,
		billHistory.ChargeMonth,
		billHistory.ElectricityCost,
		billHistory.ElectricityCostCommon,
		billHistory.ElectricityCostTax,
		billHistory.ElectricityCostFund,
		billHistory.ElectricityCostTotal,
		billHistory.WaterCostSupply,
		billHistory.WaterCostSewer,
		billHistory.WaterCostCommon,
		billHistory.WaterCostTotal,
		billHistory.TotalCost,
		billHistory.BuildingId,
		billHistory.BillHistoryId,
	)
	if err != nil {
		return fmt.Errorf("error updating bill_history: %w", err)
	}

	return nil
}

func (m *mysqlRepository) DeleteBillHistoryById(id int) error {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `DELETE FROM bill_histories WHERE bill_history_id = ?`
	_, err := m.DB.ExecContext(ctx, query, id)
	if err != nil {
		return fmt.Errorf("error deleting bill_history: %w", err)
	}

	return nil
}

func (m *mysqlRepository) GetBillHistoryByChargeMonth(month string, buildingId int) ([]*BillHistory, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `
		SELECT 
			bill_history_id,
			room_number,
			charge_month,
			electricity_cost,
			electricity_cost_common,
			electricity_cost_tax,
			electricity_cost_fund,
			electricity_cost_total,
			water_cost_supply,
			water_cost_sewer,
			water_cost_common,
			water_cost_total,
			total_cost,
			building_id
		FROM bill_histories
		WHERE charge_month = ? AND building_id = ?
	`

	var billHistories []*BillHistory
	err := m.DB.SelectContext(ctx, &billHistories, query, month, buildingId)
	if err != nil {
		return nil, fmt.Errorf("error getting bill_histories by charge month: %w", err)
	}

	return billHistories, nil
}
