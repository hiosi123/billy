package models

import (
	"context"
	"fmt"
	"time"
)

func (m *mysqlRepository) AllFloors() ([]*Floor, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `SELECT floor_id, floor, floor_space, created_at, updated_at, building_id FROM floors`

	var floors []*Floor
	err := m.DB.SelectContext(ctx, &floors, query)
	if err != nil {
		return nil, fmt.Errorf("error getting floors: %w", err)
	}

	return floors, nil
}

func (m *mysqlRepository) GetFloorById(id int) (*Floor, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `SELECT floor_id, floor, floor_space, created_at, updated_at, building_id FROM floors WHERE floor_id = ?`

	var floor Floor
	err := m.DB.GetContext(ctx, &floor, query, id)
	if err != nil {
		return nil, fmt.Errorf("error getting floor by id: %w", err)
	}

	return &floor, nil
}

func (m *mysqlRepository) CreateFloor(floor *Floor) (*Floor, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `INSERT INTO floors (floor, floor_space, building_id) VALUES (?, ?, ?)`
	result, err := m.DB.ExecContext(ctx, query, floor.Floor, floor.FloorSpace, floor.BuildingId)
	if err != nil {
		return nil, fmt.Errorf("error creating floor: %w", err)
	}

	id, err := result.LastInsertId()
	if err != nil {
		return nil, fmt.Errorf("error getting last insert id: %w", err)
	}
	floor.FloorId = int(id)

	return floor, nil
}

func (m *mysqlRepository) UpdateFloorById(floor *Floor) error {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `UPDATE floors SET floor = ?, floor_space = ? WHERE floor_id = ?`
	_, err := m.DB.ExecContext(ctx, query, floor.Floor, floor.FloorSpace, floor.FloorId)
	if err != nil {
		return fmt.Errorf("error updating floor by id: %w", err)
	}

	return nil
}

func (m *mysqlRepository) DeleteFloorById(id int) error {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `DELETE FROM floors WHERE floor_id = ?`
	_, err := m.DB.ExecContext(ctx, query, id)
	if err != nil {
		return fmt.Errorf("error deleting floor by id: %w", err)
	}

	return nil
}

func (m *mysqlRepository) GetFloorsByBuildingId(buildingId int) ([]*Floor, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `SELECT floor_id, floor, floor_space, created_at, updated_at, building_id FROM floors WHERE building_id = ?`

	var floors []*Floor
	err := m.DB.SelectContext(ctx, &floors, query, buildingId)
	if err != nil {
		return nil, fmt.Errorf("error getting floors by building id: %w", err)
	}

	return floors, nil
}
