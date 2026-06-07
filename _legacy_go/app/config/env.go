package config

import (
	"log"
	"os"

	"github.com/joho/godotenv"
	"github.com/mstoykov/envconfig"
)

var (
	envVars EnvVars
)

type EnvVars struct {
	BF_DSN string `envconfig:"BF_DSN" default:""`

	SERVER_PORT string `envconfig:"SERVER_PORT" default:":3000"`

	DB_DRIVER          string `envconfig:"DB_DRIVER" default:"mysql"`
	MAX_OPEN_CONN      int    `envconfig:"MAX_OPEN_CONN" default:"2"`
	MAX_IDEL_CONN      int    `envconfig:"MAX_IDEL_CONN" default:"0"`
	MAX_CONN_TIME      int    `envconfig:"MAX_CONN_TIME" default:"0"`
	MAX_IDEL_CONN_TIME int    `envconfig:"MAX_IDEL_CONN_TIME" default:"0"`

	API_KEY    string `envconfig:"API_KEY" default:""`
	SECRET_KEY string `envconfig:"SECRET_KEY" default:""`

	CORS_1 string `envconfig:"CORS_1" default:"http://localhost:3000"`
	CORS_2 string `envconfig:"CORS_2" default:"http://localhost:5500"`
	CORS_3 string `envconfig:"CORS_3" default:"http://127.0.0.1:5500"`
	CORS_4 string `envconfig:"CORS_4" default:"http://localhost:5502"`
}

func LoadEnv() {

	if err := godotenv.Load(); err != nil {
		log.Printf("No .env file found")
		log.Panic(err)
	}

	if os.Getenv("MAX_OPEN_CONN") == "" {
		os.Unsetenv("MAX_OPEN_CONN")
	}
	if os.Getenv("MAX_IDEL_CONN") == "" {
		os.Unsetenv("MAX_IDEL_CONN")
	}
	if os.Getenv("MAX_IDEL_CONN_TIME") == "" {
		os.Unsetenv("MAX_IDEL_CONN_TIME")
	}

	var env EnvVars
	err := envconfig.Process("", &env)
	if err != nil {
		log.Panic(err)
	}

	envVars = env
}

func GetEnv() *EnvVars {
	return &envVars
}
