package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/tls1641/buiildingFee/app"
	"github.com/tls1641/buiildingFee/app/apis"
	"github.com/tls1641/buiildingFee/app/config"
	db "github.com/tls1641/buiildingFee/app/database"
	"github.com/tls1641/buiildingFee/app/middleware"
	"github.com/tls1641/buiildingFee/app/models"
	"github.com/tls1641/buiildingFee/app/routes"
)

func main() {
	// 설정값 로드
	config.LoadEnv()
	// db 시작
	db.InitDB()
	// db 연결
	conn := db.GetConnection()
	// appplication 생성
	app := app.NewApplication(models.New(conn, "mysql"), config.GetEnv())
	// handlers 생성
	handlers := apis.NewHandlers(app)

	// gin
	r := gin.Default()
	// CORS 설정
	r.Use(middleware.CORS())
	// routes
	routes.BuildRouters(r, handlers)

	srv := &http.Server{
		Addr:              config.GetEnv().SERVER_PORT,
		Handler:           r.Handler(),
		IdleTimeout:       30 * time.Second,
		ReadTimeout:       30 * time.Second,
		ReadHeaderTimeout: 30 * time.Second,
		WriteTimeout:      30 * time.Second,
	}

	go func() {
		log.Printf("Starting server on: %v", srv.Addr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %s\n", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		log.Fatal("Server forced to shutdown:", err)
	}

	log.Println("Server exited")
}
