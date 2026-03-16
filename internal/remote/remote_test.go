package remote

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestReadWriteRemotes(t *testing.T) {
	cfg := &RemotesConfig{
		Remotes: []Remote{
			{Name: "prod", Host: "deploy@prod.example.com"},
			{Name: "staging", Host: "deploy@staging.example.com"},
		},
	}

	if len(cfg.Remotes) != 2 {
		t.Errorf("Expected 2 remotes, got %d", len(cfg.Remotes))
	}
	if cfg.Remotes[0].Name != "prod" {
		t.Errorf("Expected first remote 'prod', got '%s'", cfg.Remotes[0].Name)
	}
}

func TestAddRemoteDuplicate(t *testing.T) {
	cfg := &RemotesConfig{
		Remotes: []Remote{
			{Name: "prod", Host: "deploy@prod.example.com"},
		},
	}

	found := false
	for _, r := range cfg.Remotes {
		if r.Name == "prod" {
			found = true
		}
	}
	if !found {
		t.Error("Expected to find remote 'prod'")
	}
}

func TestGetRemoteNotFound(t *testing.T) {
	cfg := &RemotesConfig{
		Remotes: []Remote{
			{Name: "prod", Host: "deploy@prod.example.com"},
		},
	}

	found := false
	for _, r := range cfg.Remotes {
		if r.Name == "staging" {
			found = true
		}
	}
	if found {
		t.Error("Expected 'staging' to not be found")
	}
	_ = cfg
}

func TestFormatRemoteList(t *testing.T) {
	remotes := []Remote{
		{Name: "prod", Host: "deploy@prod.example.com"},
		{Name: "staging", Host: "deploy@staging.example.com"},
	}
	output := FormatRemoteList(remotes)
	if output == "" {
		t.Error("Expected non-empty output")
	}

	output = FormatRemoteList(nil)
	if output != "No remotes configured.\n" {
		t.Errorf("Expected 'No remotes configured.', got: %s", output)
	}
}

func TestRemoteConfigRoundTrip(t *testing.T) {
	tmpDir := t.TempDir()
	tmpFile := filepath.Join(tmpDir, "remotes.json")

	cfg := &RemotesConfig{
		Remotes: []Remote{
			{Name: "test", Host: "user@host"},
		},
	}

	// Write
	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		t.Fatalf("Failed to marshal: %v", err)
	}
	if err := os.WriteFile(tmpFile, data, 0644); err != nil {
		t.Fatalf("Failed to write: %v", err)
	}

	// Read back
	readData, err := os.ReadFile(tmpFile)
	if err != nil {
		t.Fatalf("Failed to read: %v", err)
	}
	var readCfg RemotesConfig
	if err := json.Unmarshal(readData, &readCfg); err != nil {
		t.Fatalf("Failed to unmarshal: %v", err)
	}
	if len(readCfg.Remotes) != 1 {
		t.Errorf("Expected 1 remote, got %d", len(readCfg.Remotes))
	}
	if readCfg.Remotes[0].Host != "user@host" {
		t.Errorf("Expected host 'user@host', got '%s'", readCfg.Remotes[0].Host)
	}
}
