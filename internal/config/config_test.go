package config

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestOpenClawConfigRoundTrip(t *testing.T) {
	// Create a temp config file
	tmpDir := t.TempDir()
	cfgPath := filepath.Join(tmpDir, "openclaw.json")

	cfg := &OpenClawConfig{}
	cfg.Agents.List = []Agent{
		{ID: "test-agent", Name: "Test", Model: "claude-opus-4-6", Role: "tester"},
	}
	cfg.Bindings = []Binding{
		{AgentID: "test-agent", Discord: &Discord{ChannelID: "123", ServerID: "456"}},
	}

	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	if err := os.WriteFile(cfgPath, data, 0644); err != nil {
		t.Fatalf("write: %v", err)
	}

	// Read it back
	readData, err := os.ReadFile(cfgPath)
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	var readCfg OpenClawConfig
	if err := json.Unmarshal(readData, &readCfg); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}

	if len(readCfg.Agents.List) != 1 {
		t.Fatalf("expected 1 agent, got %d", len(readCfg.Agents.List))
	}
	if readCfg.Agents.List[0].ID != "test-agent" {
		t.Errorf("expected ID 'test-agent', got %q", readCfg.Agents.List[0].ID)
	}
	if readCfg.Agents.List[0].Name != "Test" {
		t.Errorf("expected Name 'Test', got %q", readCfg.Agents.List[0].Name)
	}
	if len(readCfg.Bindings) != 1 {
		t.Fatalf("expected 1 binding, got %d", len(readCfg.Bindings))
	}
	if readCfg.Bindings[0].Discord.ChannelID != "123" {
		t.Errorf("expected Discord channel '123', got %q", readCfg.Bindings[0].Discord.ChannelID)
	}
}

func TestAgentModelFlexibility(t *testing.T) {
	// Test string model
	jsonStr := `{"agents":{"list":[{"id":"a","model":"claude-opus-4-6"}]}}`
	var cfg OpenClawConfig
	if err := json.Unmarshal([]byte(jsonStr), &cfg); err != nil {
		t.Fatalf("unmarshal string model: %v", err)
	}
	if s, ok := cfg.Agents.List[0].Model.(string); !ok || s != "claude-opus-4-6" {
		t.Errorf("expected string model, got %T: %v", cfg.Agents.List[0].Model, cfg.Agents.List[0].Model)
	}

	// Test map model
	jsonMap := `{"agents":{"list":[{"id":"b","model":{"primary":"openai/gpt-5","fallbacks":["anthropic/claude"]}}]}}`
	var cfg2 OpenClawConfig
	if err := json.Unmarshal([]byte(jsonMap), &cfg2); err != nil {
		t.Fatalf("unmarshal map model: %v", err)
	}
	m, ok := cfg2.Agents.List[0].Model.(map[string]interface{})
	if !ok {
		t.Fatalf("expected map model, got %T", cfg2.Agents.List[0].Model)
	}
	if m["primary"] != "openai/gpt-5" {
		t.Errorf("expected primary 'openai/gpt-5', got %v", m["primary"])
	}
}

func TestDefaultsModelParsing(t *testing.T) {
	jsonStr := `{"agents":{"defaults":{"model":{"primary":"openai-codex/gpt-5.4","fallbacks":["anthropic/claude-sonnet-4-6"]}},"list":[]}}`
	var cfg OpenClawConfig
	if err := json.Unmarshal([]byte(jsonStr), &cfg); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	m, ok := cfg.Agents.Defaults.Model.(map[string]interface{})
	if !ok {
		t.Fatalf("expected map default model, got %T", cfg.Agents.Defaults.Model)
	}
	if m["primary"] != "openai-codex/gpt-5.4" {
		t.Errorf("expected primary 'openai-codex/gpt-5.4', got %v", m["primary"])
	}
}

func TestUserConfigDefaults(t *testing.T) {
	// ReadUserConfig should return empty config for nonexistent file
	// We can't easily test this without mocking the path, but we can test the struct
	cfg := &UserConfig{Fleet: make(map[string]interface{})}
	if len(cfg.Fleet) != 0 {
		t.Errorf("expected empty fleet map")
	}
	cfg.Fleet["test"] = "value"
	if cfg.Fleet["test"] != "value" {
		t.Errorf("expected 'value', got %v", cfg.Fleet["test"])
	}
}
