package models

import (
	"context"
	"fmt"
	"time"
)

func (m *mysqlRepository) AllUsers() ([]*User, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `SELECT user_id, username, password, role, created_at, updated_at FROM users`

	var users []*User
	err := m.DB.SelectContext(ctx, &users, query)
	if err != nil {
		return nil, fmt.Errorf("error getting users: %w", err)
	}
	return users, nil
}

func (m *mysqlRepository) GetUserById(id int) (*User, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `SELECT user_id, username, password, role, created_at, updated_at FROM users WHERE user_id = ?`
	var user User
	err := m.DB.GetContext(ctx, &user, query, id)
	if err != nil {
		return nil, fmt.Errorf("error getting user by id: %w", err)
	}
	return &user, nil
}

func (m *mysqlRepository) GetUserByUsername(username string) (*User, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `SELECT user_id, username, password, role, created_at, updated_at FROM users WHERE username = ?`
	var user User
	err := m.DB.GetContext(ctx, &user, query, username)
	if err != nil {
		return nil, fmt.Errorf("error getting user by username: %w", err)
	}

	return &user, nil
}

func (m *mysqlRepository) CreateUser(user *User) (*User, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `INSERT INTO users (username, password, role, created_at, updated_at) VALUES (?, ?, ?, NOW(), NOW())`
	result, err := m.DB.ExecContext(ctx, query, user.Username, user.Password, user.Role)
	if err != nil {
		return nil, fmt.Errorf("error creating user: %w", err)
	}
	id, err := result.LastInsertId()
	if err != nil {
		return nil, fmt.Errorf("error getting last insert id: %w", err)
	}
	user.UserId = int(id)
	return user, nil
}

func (m *mysqlRepository) UpdateUserById(user *User) error {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `UPDATE users SET username = ?, password = ?, role = ?, updated_at = NOW() WHERE user_id = ?`

	_, err := m.DB.ExecContext(ctx, query, user.Username, user.Password, user.Role, user.UserId)
	if err != nil {
		return fmt.Errorf("error updating user: %w", err)
	}
	return nil
}

func (m *mysqlRepository) DeleteUserById(id int) error {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	query := `DELETE FROM users WHERE user_id = ?`

	_, err := m.DB.ExecContext(ctx, query, id)
	if err != nil {
		return fmt.Errorf("error deleting user: %w", err)
	}

	return nil
}
