package models

import (
	"context"
	"fmt"
	"time"
)

func (m *mysqlRepository) AllBuildings() ([]*Building, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `SELECT building_id, building_name, building_address, building_floors, elevator, owner, created_at, updated_at FROM buildings`

	var buildings []*Building
	err := m.DB.SelectContext(ctx, &buildings, query)
	if err != nil {
		return nil, fmt.Errorf("error getting buildings: %w", err)
	}

	return buildings, nil
}

func (m *mysqlRepository) GetBuildingById(id int) (*Building, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `SELECT building_id, building_name, building_address, building_floors, elevator, owner, created_at, updated_at FROM buildings WHERE building_id = ?`

	var building Building
	err := m.DB.GetContext(ctx, &building, query, id)
	if err != nil {
		return nil, fmt.Errorf("error getting building by id: %w", err)
	}

	return &building, nil
}

func (m *mysqlRepository) GetBuildingsByUserId(userId int) ([]*Building, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	query := `SELECT building_id, building_name, building_address, building_floors, elevator, owner, created_at, updated_at FROM buildings WHERE user_id = ?`

	var buildings []*Building
	err := m.DB.SelectContext(ctx, &buildings, query, userId)
	if err != nil {
		return nil, fmt.Errorf("error getting buildings by user id: %w", err)
	}
	return buildings, nil
}

func (m *mysqlRepository) CreateBuilding(building *Building) (*Building, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `INSERT INTO buildings (building_name, building_address, building_floors, elevator, owner) VALUES (?, ?, ?, ?, ?)`
	result, err := m.DB.ExecContext(ctx, query, building.BuildingName, building.BuildingFloors, building.Elevator, building.Owner)
	if err != nil {
		return nil, fmt.Errorf("error creating building: %w", err)
	}

	id, err := result.LastInsertId()
	if err != nil {
		return nil, fmt.Errorf("error getting last insert id: %w", err)
	}
	building.BuildingId = int(id)

	return building, nil
}

func (m *mysqlRepository) UpdateBuildingById(building *Building) error {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `UPDATE buildings SET building_name = ?, building_address = ?, building_floors = ?, elevator = ?, owner = ? WHERE building_id = ?`
	_, err := m.DB.ExecContext(ctx, query, building.BuildingName, building.BuildingFloors, building.Elevator, building.Owner, building.BuildingId)
	if err != nil {
		return fmt.Errorf("error updating building: %w", err)
	}

	return nil
}

func (m *mysqlRepository) DeleteBuildingById(id int) error {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `DELETE FROM buildings WHERE building_id = ?`
	_, err := m.DB.ExecContext(ctx, query, id)
	if err != nil {
		return fmt.Errorf("error deleting building: %w", err)
	}

	return nil
}
