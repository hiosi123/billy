package models

import (
	"context"
	"fmt"
	"time"
)

func (m *mysqlRepository) AllBuildingFees() ([]*BuildingFee, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `
		SELECT 
			building_id,
			general_management_fee,
			public_inspection_fee,
			fire_management_fee,
			elevator_maintenance_fee,
			septic_tank_management_fee,
			electrical_management_fee,
			parking_management_fee
		FROM building_fees
	`

	var buildingFees []*BuildingFee
	err := m.DB.SelectContext(ctx, &buildingFees, query)
	if err != nil {
		return nil, fmt.Errorf("error getting building_feess: %w", err)
	}

	return buildingFees, nil
}

func (m *mysqlRepository) GetBuildingFeeById(id int) (*BuildingFee, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `
		SELECT 
			building_id,
			general_management_fee,
			public_inspection_fee,
			fire_management_fee,
			elevator_maintenance_fee,
			septic_tank_management_fee,
			electrical_management_fee,
			parking_management_fee
		FROM building_fees
		WHERE building_id = ?
	`

	var buildingFee BuildingFee
	err := m.DB.GetContext(ctx, &buildingFee, query, id)
	if err != nil {
		return nil, fmt.Errorf("error getting building_fees by id: %w", err)
	}

	return &buildingFee, nil
}

func (m *mysqlRepository) CreateBuildingFee(buildingFee *BuildingFee) (*BuildingFee, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `
		INSERT INTO building_fees (
			building_id,
			general_management_fee,
			public_inspection_fee,
			fire_management_fee,
			elevator_maintenance_fee,
			septic_tank_management_fee,
			electrical_management_fee,
			parking_management_fee
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
	`

	_, err := m.DB.ExecContext(ctx, query,
		buildingFee.BuildingId,
		buildingFee.GeneralManagementFee,
		buildingFee.PublicInspectionFee,
		buildingFee.FireManagementFee,
		buildingFee.ElevatorMaintenanceFee,
		buildingFee.SepticTankManagementFee,
		buildingFee.ElectricalManagementFee,
		buildingFee.ParkingManagementFee,
	)
	if err != nil {
		return nil, fmt.Errorf("error creating building_fees: %w", err)
	}

	return buildingFee, nil
}

func (m *mysqlRepository) UpdateBuildingFeeById(buildingFee *BuildingFee) error {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `
		UPDATE building_fees SET 
			general_management_fee = ?,
			public_inspection_fee = ?,
			fire_management_fee = ?,
			elevator_maintenance_fee = ?,
			septic_tank_management_fee = ?,
			electrical_management_fee = ?,
			parking_management_fee = ?
		WHERE building_id = ?
	`

	_, err := m.DB.ExecContext(ctx, query,
		buildingFee.GeneralManagementFee,
		buildingFee.PublicInspectionFee,
		buildingFee.FireManagementFee,
		buildingFee.ElevatorMaintenanceFee,
		buildingFee.SepticTankManagementFee,
		buildingFee.ElectricalManagementFee,
		buildingFee.ParkingManagementFee,
		buildingFee.BuildingId,
	)
	if err != nil {
		return fmt.Errorf("error updating building_fees: %w", err)
	}

	return nil
}

func (m *mysqlRepository) DeleteBuildingFeeById(id int) error {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `DELETE FROM building_fees WHERE building_id = ?`
	_, err := m.DB.ExecContext(ctx, query, id)
	if err != nil {
		return fmt.Errorf("error deleting building_fees: %w", err)
	}

	return nil
}

func (m *mysqlRepository) GetBuildingFeeByBuildingId(buildingId int) (*BuildingFee, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `
		SELECT 
			building_id,
			general_management_fee,
			public_inspection_fee,
			fire_management_fee,
			elevator_maintenance_fee,
			septic_tank_management_fee,
			electrical_management_fee,
			parking_management_fee
		FROM building_fees
		WHERE building_id = ?
	`

	var buildingFee BuildingFee
	err := m.DB.GetContext(ctx, &buildingFee, query, buildingId)
	if err != nil {
		return nil, fmt.Errorf("error getting building_fees by building_id: %w", err)
	}

	return &buildingFee, nil
}
