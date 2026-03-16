package cmd

import (
	"testing"
)

func TestDeployCmdExists(t *testing.T) {
	if deployCmd == nil {
		t.Fatal("deployCmd is nil")
	}
	if deployCmd.Use != "deploy <id>" {
		t.Errorf("Expected Use='deploy <id>', got '%s'", deployCmd.Use)
	}
}

func TestDeployCmdFlags(t *testing.T) {
	flags := []string{"from", "name", "role", "emoji", "channel"}
	for _, flag := range flags {
		f := deployCmd.Flags().Lookup(flag)
		if f == nil {
			t.Errorf("Expected flag '--%s' to exist", flag)
		}
	}
}

func TestDeployCmdHelp(t *testing.T) {
	// Verify help text is set
	if deployCmd.Short == "" {
		t.Error("Expected non-empty Short description")
	}
	if deployCmd.Long == "" {
		t.Error("Expected non-empty Long description")
	}
}
