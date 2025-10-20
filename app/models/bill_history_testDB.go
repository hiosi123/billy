package models

func (t *testRepository) AllBillHistories() ([]*BillHistory, error) {
	return nil, nil
}
func (t *testRepository) GetBillHistoryById(id int) (*BillHistory, error) {
	return nil, nil
}
func (t *testRepository) CreateBillHistory(billHistory *BillHistory) (*BillHistory, error) {
	return nil, nil
}
func (t *testRepository) UpdateBillHistoryById(billHistory *BillHistory) error {
	return nil
}
func (t *testRepository) DeleteBillHistoryById(id int) error {
	return nil
}
func (t *testRepository) GetBillHistoryByChargeMonth(month string, buildingId int) ([]*BillHistory, error) {
	return nil, nil
}
