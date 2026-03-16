package fleet

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/cyperx84/clawforge/internal/config"
)

func TestDetectDriftWithPaths(t *testing.T) {
	// Create temp agents dir
	tmpDir := t.TempDir()

	// Create disk agents: alpha, beta
	for _, id := range []string{"alpha", "beta"} {
		dir := filepath.Join(tmpDir, id)
		os.MkdirAll(dir, 0755)
		os.WriteFile(filepath.Join(dir, "SOUL.md"), []byte("# SOUL.md - "+id), 0644)
	}

	// Config has: alpha, gamma
	cfg := &config.OpenClawConfig{}
	cfg.Agents.List = []config.Agent{
		{ID: "alpha", Name: "Alpha", Model: "claude-opus-4-6"},
		{ID: "gamma", Name: "Gamma", Model: "claude-opus-4-6"},
	}

	result, err := DetectDriftWithPaths(tmpDir, cfg)
	if err != nil {
		t.Fatalf("DetectDriftWithPaths failed: %v", err)
	}

	// beta is disk-only
	if len(result.DiskOnly) != 1 || result.DiskOnly[0] != "beta" {
		t.Errorf("Expected DiskOnly=[beta], got %v", result.DiskOnly)
	}

	// gamma is config-only
	if len(result.ConfigOnly) != 1 || result.ConfigOnly[0] != "gamma" {
		t.Errorf("Expected ConfigOnly=[gamma], got %v", result.ConfigOnly)
	}

	// alpha is in sync
	if len(result.InSync) != 1 || result.InSync[0] != "alpha" {
		t.Errorf("Expected InSync=[alpha], got %v", result.InSync)
	}
}

func TestDetectDriftNoDrift(t *testing.T) {
	tmpDir := t.TempDir()

	// Create disk agent: alpha
	dir := filepath.Join(tmpDir, "alpha")
	os.MkdirAll(dir, 0755)
	os.WriteFile(filepath.Join(dir, "SOUL.md"), []byte("test"), 0644)

	// Config also has alpha
	cfg := &config.OpenClawConfig{}
	cfg.Agents.List = []config.Agent{
		{ID: "alpha", Name: "Alpha", Model: "claude-opus-4-6"},
	}

	result, err := DetectDriftWithPaths(tmpDir, cfg)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if len(result.DiskOnly) != 0 {
		t.Errorf("Expected no DiskOnly, got %v", result.DiskOnly)
	}
	if len(result.ConfigOnly) != 0 {
		t.Errorf("Expected no ConfigOnly, got %v", result.ConfigOnly)
	}
}

func TestFormatSyncResult(t *testing.T) {
	result := &SyncResult{
		DiskOnly:   []string{"orphan1"},
		ConfigOnly: []string{"ghost1"},
		InSync:     []string{"ok1"},
	}
	output := FormatSyncResult(result)
	if output == "" {
		t.Error("Expected non-empty output")
	}

	// No drift case
	noResult := &SyncResult{}
	output = FormatSyncResult(noResult)
	if output != "No drift detected. All agents are in sync.\n" {
		t.Errorf("Expected no-drift message, got: %s", output)
	}
}

func TestFormatSyncJSON(t *testing.T) {
	result := &SyncResult{
		DiskOnly:   []string{"orphan"},
		ConfigOnly: []string{"ghost"},
		InSync:     []string{"ok"},
	}
	jsonStr, err := FormatSyncJSON(result)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if jsonStr == "" {
		t.Error("Expected non-empty JSON")
	}
}
