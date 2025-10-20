package models

func (t *testRepository) AllRooms() ([]*Room, error) {
	return nil, nil
}

func (t *testRepository) GetRoomById(id int) (*Room, error) {
	return nil, nil
}

func (t *testRepository) CreateRoom(room *Room) (*Room, error) {
	return nil, nil
}

func (t *testRepository) UpdateRoomById(room *Room) error {
	return nil
}

func (t *testRepository) DeleteRoomById(id int) error {
	return nil
}

func (t *testRepository) GetRoomsByBuildingId(buildingId int) ([]*Room, error) {
	return nil, nil
}

func (t *testRepository) GetRoomsByFloorId(floorId int) ([]*Room, error) {
	return nil, nil
}
