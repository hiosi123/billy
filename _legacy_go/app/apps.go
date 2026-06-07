package app

import (
	"github.com/tls1641/buiildingFee/app/config"
	"github.com/tls1641/buiildingFee/app/models"
)

type Application struct {
	Models *models.Models
	Config *config.EnvVars
}

func NewApplication(models *models.Models, config *config.EnvVars) *Application {
	return &Application{
		Models: models,
		Config: config,
	}
}

func (app *Application) GetModels() *models.Models {
	return app.Models
}

func (app *Application) GetConfig() *config.EnvVars {
	return app.Config
}

func (app *Application) SetModels(models *models.Models) {
	app.Models = models
}

func (app *Application) SetConfig(config *config.EnvVars) {
	app.Config = config
}
