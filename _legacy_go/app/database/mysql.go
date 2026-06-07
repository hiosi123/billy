package db

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"sync"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/tls1641/buiildingFee/app/config"
)

var (
	conn *sql.DB
	once sync.Once
	mu   sync.RWMutex
)

func InitDB() {
	once.Do(func() {
		db, err := sql.Open("mysql", config.GetEnv().BF_DSN)
		if err != nil {
			log.Fatal(err)
		}

		db.SetMaxOpenConns(config.GetEnv().MAX_OPEN_CONN)
		db.SetMaxIdleConns(config.GetEnv().MAX_IDEL_CONN_TIME)
		db.SetConnMaxIdleTime(time.Duration(config.GetEnv().MAX_IDEL_CONN_TIME))

		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		if err = db.PingContext(ctx); err != nil {
			db.Close()
			log.Fatalf("Failed to ping database: %v", err)
		}

		mu.Lock()
		conn = db
		mu.Unlock()

		log.Println("Database connection established successfully")
	})
}

func GetConnection() *sql.DB {
	mu.RLock()
	defer mu.RUnlock()
	return conn
}

func HealthCheck(ctx context.Context) error {
	mu.RLock()
	db := conn
	mu.RUnlock()

	if db == nil {
		return fmt.Errorf("database connection is nil")
	}

	if err := db.PingContext(ctx); err != nil {
		return fmt.Errorf("database health check failed: %w", err)
	}

	return nil
}

func Close() error {
	mu.Lock()
	defer mu.Unlock()

	if conn != nil {
		err := conn.Close()
		conn = nil
		return err
	}
	return nil
}

func Stats() map[string]interface{} {
	mu.RLock()
	defer mu.RUnlock()

	if conn == nil {
		return map[string]interface{}{
			"status": "disconnected",
		}
	}

	stats := conn.Stats()
	return map[string]interface{}{
		"max_open_connections": stats.MaxOpenConnections,
		"open_connections":     stats.OpenConnections,
		"in_use":               stats.InUse,
		"idle":                 stats.Idle,
		"wait_count":           stats.WaitCount,
		"wait_duration":        stats.WaitDuration.String(),
		"max_idle_closed":      stats.MaxIdleClosed,
		"max_idle_time_closed": stats.MaxIdleTimeClosed,
		"max_lifetime_closed":  stats.MaxLifetimeClosed,
	}
}
