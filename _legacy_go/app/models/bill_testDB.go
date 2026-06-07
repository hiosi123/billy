package models

func (t *testRepository) AllBills() ([]*Bill, error) {
	return nil, nil
}

func (t *testRepository) GetBillById(id int) (*Bill, error) {
	return nil, nil
}

func (t *testRepository) CreateBill(bill *Bill) (*Bill, error) {
	return nil, nil
}

func (t *testRepository) UpdateBillById(bill *Bill) error {
	return nil
}

func (t *testRepository) DeleteBillById(id int) error {
	return nil
}

func (t *testRepository) GetBillByMonth(month string, buildingId int) ([]*Bill, error) {
	return nil, nil
}

func (t *testRepository) GetBillsByCondition(month string, roomId, floorId, buildingId int) ([]*BillInfo, error) {
	return nil, nil
}
