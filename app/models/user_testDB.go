package models

func (m *testRepository) AllUsers() ([]*User, error) {
	return nil, nil
}

func (m *testRepository) GetUserById(id int) (*User, error) {
	return nil, nil
}

func (m *testRepository) GetUserByUsername(username string) (*User, error) {
	return nil, nil
}

func (m *testRepository) CreateUser(user *User) (*User, error) {
	return nil, nil
}

func (m *testRepository) UpdateUserById(user *User) error {
	return nil
}

func (m *testRepository) DeleteUserById(id int) error {
	return nil
}
