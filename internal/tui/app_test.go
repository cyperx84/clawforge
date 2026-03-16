package tui

import (
	"testing"
)

func TestNewApp(t *testing.T) {
	app := NewApp()
	if app == nil {
		t.Fatal("NewApp returned nil")
	}
	if app.Screen != "fleet" {
		t.Errorf("expected screen 'fleet', got %q", app.Screen)
	}
	if app.Selected != 0 {
		t.Errorf("expected selected 0, got %d", app.Selected)
	}
}

func TestAppInit(t *testing.T) {
	app := NewApp()
	cmd := app.Init()
	if cmd != nil {
		t.Error("Init should return nil cmd")
	}
}

func TestAppViewScreens(t *testing.T) {
	app := NewApp()

	screens := []string{"fleet", "detail", "cost", "logs", "help"}
	for _, screen := range screens {
		app.Screen = screen
		view := app.View()
		if view == "" {
			t.Errorf("View for screen %q returned empty string", screen)
		}
	}
}
