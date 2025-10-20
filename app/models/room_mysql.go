package models

import (
	"context"
	"fmt"
	"time"
)

func (m *mysqlRepository) AllRooms() ([]*Room, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `
	SELECT 
		room_id, 
		room_number,
		room_base_cost,
		measure_machine, 
		room_name, 
		room_space, 
		measure_no, 
		strict_water, 
		strict_electricity, 
		measure_multiply, 
		created_at, 
		updated_at, 
		floor_id, 
		building_id 
	FROM rooms`

	var rooms []*Room
	err := m.DB.SelectContext(ctx, &rooms, query)
	if err != nil {
		return nil, fmt.Errorf("error getting rooms: %w", err)
	}

	return rooms, nil
}

func (m *mysqlRepository) GetRoomById(id int) (*Room, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `
	SELECT 
		room_id, 
		room_number, 
		room_base_cost,
		measure_machine,
		room_name, 
		room_space, 
		measure_no, 
		strict_water, 
		strict_electricity, 
		measure_multiply, 
		created_at, 
		updated_at, 
		floor_id, 
		building_id 
	FROM rooms 
	WHERE room_id = ?`

	var room Room
	err := m.DB.GetContext(ctx, &room, query, id)
	if err != nil {
		return nil, fmt.Errorf("error getting room by id: %w", err)
	}

	return &room, nil
}

func (m *mysqlRepository) CreateRoom(room *Room) (*Room, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `INSERT INTO rooms (room_number, room_base_cost, measure_machine, room_name, room_space, strict_water, strict_electricity, measure_no, measure_multiply, floor_id, building_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
	result, err := m.DB.ExecContext(ctx, query, room.RoomNumber, room.RoomBaseCost, room.MeasureMachine, room.RoomName, room.RoomSpace, room.StrictWater, room.StrictElectricity, room.MeasureNo, room.MeasureMultiply, room.FloorId, room.BuildingId)
	if err != nil {
		return nil, fmt.Errorf("error creating room: %w", err)
	}

	id, err := result.LastInsertId()
	if err != nil {
		return nil, fmt.Errorf("error getting last insert id: %w", err)
	}
	room.RoomId = int(id)

	return room, nil
}

func (m *mysqlRepository) UpdateRoomById(room *Room) error {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `UPDATE rooms SET room_number = ?, room_base_cost = ?, measure_machine = ?, room_name = ?, room_space = ?, strict_water = ?, strict_electricity = ?, measure_no = ?, measure_multiply = ? WHERE room_id = ?`
	_, err := m.DB.ExecContext(ctx, query, room.RoomNumber, room.RoomBaseCost, room.MeasureMachine, room.RoomName, room.RoomSpace, room.StrictWater, room.StrictElectricity, room.MeasureNo, room.MeasureMultiply, room.RoomId)
	if err != nil {
		return fmt.Errorf("error updating room: %w", err)
	}

	return nil
}

func (m *mysqlRepository) DeleteRoomById(id int) error {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `DELETE FROM rooms WHERE room_id = ?`
	_, err := m.DB.ExecContext(ctx, query, id)
	if err != nil {
		return fmt.Errorf("error deleting room: %w", err)
	}

	return nil
}

func (m *mysqlRepository) GetRoomsByBuildingId(buildingId int) ([]*Room, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `SELECT 
		room_id, 
		room_number, 
		room_base_cost, 
		measure_machine, 
		room_name, 
		room_space, 
		strict_water, 
		strict_electricity, 
		measure_no, 
		measure_multiply, 
		r.created_at, 
		r.updated_at, 
		r.floor_id, 
		r.building_id,
		f.floor floor
	FROM rooms r
	LEFT JOIN floors f ON r.floor_id = f.floor_id
	WHERE r.building_id = ?`
	var rooms []*Room
	err := m.DB.SelectContext(ctx, &rooms, query, buildingId)
	if err != nil {
		return nil, fmt.Errorf("error getting rooms by building id: %w", err)
	}

	return rooms, nil
}

func (m *mysqlRepository) GetRoomsByFloorId(floorId int) ([]*Room, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `SELECT room_id, room_number, room_base_cost, measure_machine, room_name, room_space, strict_water, strict_electricity, measure_no, measure_multiply, created_at, updated_at, floor_id, building_id FROM rooms WHERE floor_id = ?`

	var rooms []*Room
	err := m.DB.SelectContext(ctx, &rooms, query, floorId)
	if err != nil {
		return nil, fmt.Errorf("error getting rooms by floor id: %w", err)
	}

	return rooms, nil
}
