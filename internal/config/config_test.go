package config

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestOpenClawConfigRoundTrip(t *testing.T) {
	// Create a temp config file with a minimal config
	tmpDir := t.TempDir()
	cfgPath := filepath.Join(tmpDir, "openclaw.json")

	initial := map[string]interface{}{
		"agents": map[string]interface{}{
			"list": []interface{}{
				map[string]interface{}{"id": "test-agent", "name": "Test", "model": "claude-opus-4-6", "role": "tester"},
			},
		},
		"bindings": []interface{}{
			map[string]interface{}{"agentId": "test-agent", "match": map[string]interface{}{
				"channel": "discord",
				"peer":    map[string]interface{}{"kind": "channel", "id": "123"},
			}},
		},
	}

	data, err := json.MarshalIndent(initial, "", "  ")
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
	if readCfg.Bindings[0].AgentID != "test-agent" {
		t.Errorf("expected agentId 'test-agent', got %q", readCfg.Bindings[0].AgentID)
	}
}

// TestConfigPreservesUnknownFields is the critical test — verifies that
// reading and writing back preserves fields ClawForge doesn't know about.
// This bug caused two crash loops on 2026-03-16 by dropping gateway.mode,
// channels, tools, memory, auth, plugins, hooks, etc.
func TestConfigPreservesUnknownFields(t *testing.T) {
	tmpDir := t.TempDir()
	cfgPath := filepath.Join(tmpDir, "openclaw.json")

	// Write a full config similar to real openclaw.json
	fullConfig := `{
  "meta": {"lastTouchedVersion": "2026.3.13"},
  "auth": {"profiles": {"anthropic:default": {"provider": "anthropic"}}},
  "models": {"mode": "merge", "providers": {"zai": {"baseUrl": "https://api.z.ai"}}},
  "agents": {
    "defaults": {
      "model": {"primary": "openai-codex/gpt-5.4", "fallbacks": ["anthropic/claude-sonnet-4-6"]},
      "models": {"openai-codex/gpt-5.4": {"alias": "codex"}},
      "memorySearch": {"enabled": true},
      "heartbeat": {"every": "1h"}
    },
    "list": [
      {
        "id": "main", "name": "Claw", "default": true,
        "model": {"primary": "openai-codex/gpt-5.4", "fallbacks": ["anthropic/claude-sonnet-4-6"]},
        "workspace": "/test/workspace",
        "subagents": {"allowAgents": ["builder"]}
      },
      {"id": "builder", "name": "Builder", "model": "openai-codex/gpt-5.4", "workspace": "/test/builder"}
    ]
  },
  "tools": {"profile": "full", "exec": {"security": "full"}},
  "bindings": [
    {"agentId": "builder", "match": {"channel": "discord", "peer": {"kind": "channel", "id": "123456"}}}
  ],
  "commands": {"native": "auto"},
  "session": {"dmScope": "per-channel-peer"},
  "hooks": {"internal": {"enabled": true}},
  "channels": {
    "discord": {"enabled": true, "token": "secret-token", "guilds": {"guild1": {"channels": {"ch1": {"allow": true}}}}},
    "imessage": {"enabled": false}
  },
  "gateway": {"mode": "local", "auth": {"mode": "token", "token": "secret"}},
  "memory": {"backend": "qmd"},
  "plugins": {"entries": {"discord": {"enabled": true}}}
}`

	if err := os.WriteFile(cfgPath, []byte(fullConfig), 0644); err != nil {
		t.Fatalf("write: %v", err)
	}

	// Read config
	data, err := os.ReadFile(cfgPath)
	if err != nil {
		t.Fatalf("read: %v", err)
	}

	var raw map[string]json.RawMessage
	if err := json.Unmarshal(data, &raw); err != nil {
		t.Fatalf("unmarshal raw: %v", err)
	}

	cfg := &OpenClawConfig{raw: raw}

	// Parse agents
	if agentsRaw, ok := raw["agents"]; ok {
		var agentsMap map[string]json.RawMessage
		json.Unmarshal(agentsRaw, &agentsMap)

		if defaultsRaw, ok := agentsMap["defaults"]; ok {
			var defaultsMap map[string]json.RawMessage
			json.Unmarshal(defaultsRaw, &defaultsMap)
			if modelRaw, ok := defaultsMap["model"]; ok {
				var model interface{}
				json.Unmarshal(modelRaw, &model)
				cfg.Agents.Defaults.Model = model
			}
			cfg.Agents.Defaults.Extra = make(map[string]json.RawMessage)
			for k, v := range defaultsMap {
				if k != "model" {
					cfg.Agents.Defaults.Extra[k] = v
				}
			}
		}

		if listRaw, ok := agentsMap["list"]; ok {
			json.Unmarshal(listRaw, &cfg.Agents.List)
		}

		cfg.Agents.Extra = make(map[string]json.RawMessage)
		for k, v := range agentsMap {
			if k != "defaults" && k != "list" {
				cfg.Agents.Extra[k] = v
			}
		}
	}

	if bindingsRaw, ok := raw["bindings"]; ok {
		json.Unmarshal(bindingsRaw, &cfg.Bindings)
	}

	// Modify: add a new agent
	cfg.Agents.List = append(cfg.Agents.List, Agent{
		ID:    "new-agent",
		Name:  "New",
		Model: "openai-codex/gpt-5.4",
	})

	// Write it back using WriteOpenClawConfig's logic
	output := make(map[string]json.RawMessage)
	for k, v := range cfg.raw {
		output[k] = v
	}

	agentsMap := make(map[string]json.RawMessage)
	for k, v := range cfg.Agents.Extra {
		agentsMap[k] = v
	}
	defaultsMap := make(map[string]json.RawMessage)
	for k, v := range cfg.Agents.Defaults.Extra {
		defaultsMap[k] = v
	}
	if cfg.Agents.Defaults.Model != nil {
		modelJSON, _ := json.Marshal(cfg.Agents.Defaults.Model)
		defaultsMap["model"] = modelJSON
	}
	defaultsJSON, _ := json.Marshal(defaultsMap)
	agentsMap["defaults"] = defaultsJSON
	listJSON, _ := json.Marshal(cfg.Agents.List)
	agentsMap["list"] = listJSON
	agentsJSON, _ := json.Marshal(agentsMap)
	output["agents"] = agentsJSON
	bindingsJSON, _ := json.Marshal(cfg.Bindings)
	output["bindings"] = bindingsJSON

	outData, err := json.MarshalIndent(output, "", "  ")
	if err != nil {
		t.Fatalf("marshal output: %v", err)
	}

	// Parse the output and verify ALL fields survived
	var result map[string]json.RawMessage
	if err := json.Unmarshal(outData, &result); err != nil {
		t.Fatalf("unmarshal result: %v", err)
	}

	// Critical fields that MUST survive
	mustExist := []string{
		"meta", "auth", "models", "agents", "tools", "bindings",
		"commands", "session", "hooks", "channels", "gateway",
		"memory", "plugins",
	}
	for _, key := range mustExist {
		if _, ok := result[key]; !ok {
			t.Errorf("CRITICAL: field %q was dropped during write!", key)
		}
	}

	// Verify gateway.mode survived (this caused the crash loop)
	var gw map[string]interface{}
	json.Unmarshal(result["gateway"], &gw)
	if gw["mode"] != "local" {
		t.Errorf("gateway.mode was lost! got %v", gw["mode"])
	}

	// Verify Discord config survived
	var channels map[string]json.RawMessage
	json.Unmarshal(result["channels"], &channels)
	if _, ok := channels["discord"]; !ok {
		t.Error("channels.discord was dropped!")
	}

	// Verify new agent was added
	var agents map[string]json.RawMessage
	json.Unmarshal(result["agents"], &agents)
	var list []map[string]interface{}
	json.Unmarshal(agents["list"], &list)
	if len(list) != 3 {
		t.Errorf("expected 3 agents, got %d", len(list))
	}

	// Verify agent subagents field survived
	found := false
	for _, a := range list {
		if a["id"] == "main" {
			if _, ok := a["subagents"]; !ok {
				t.Error("agent 'main' lost subagents field!")
			}
			if _, ok := a["default"]; !ok {
				t.Error("agent 'main' lost default field!")
			}
			found = true
		}
	}
	if !found {
		t.Error("main agent not found in output")
	}

	// Verify defaults extra fields survived (memorySearch, heartbeat, models)
	var defaults map[string]json.RawMessage
	json.Unmarshal(agents["defaults"], &defaults)
	if _, ok := defaults["memorySearch"]; !ok {
		t.Error("agents.defaults.memorySearch was dropped!")
	}
	if _, ok := defaults["heartbeat"]; !ok {
		t.Error("agents.defaults.heartbeat was dropped!")
	}
	if _, ok := defaults["models"]; !ok {
		t.Error("agents.defaults.models was dropped!")
	}

	// Verify binding match field survived
	var bindings []map[string]interface{}
	json.Unmarshal(result["bindings"], &bindings)
	if len(bindings) != 1 {
		t.Fatalf("expected 1 binding, got %d", len(bindings))
	}
	if _, ok := bindings[0]["match"]; !ok {
		t.Error("binding 'match' field was dropped!")
	}
}

func TestAgentModelFlexibility(t *testing.T) {
	// Test string model
	jsonStr := `{"id":"a","model":"claude-opus-4-6"}`
	var agent Agent
	if err := json.Unmarshal([]byte(jsonStr), &agent); err != nil {
		t.Fatalf("unmarshal string model: %v", err)
	}
	if s, ok := agent.Model.(string); !ok || s != "claude-opus-4-6" {
		t.Errorf("expected string model, got %T: %v", agent.Model, agent.Model)
	}

	// Test map model
	jsonMap := `{"id":"b","model":{"primary":"openai/gpt-5","fallbacks":["anthropic/claude"]}}`
	var agent2 Agent
	if err := json.Unmarshal([]byte(jsonMap), &agent2); err != nil {
		t.Fatalf("unmarshal map model: %v", err)
	}
	m, ok := agent2.Model.(map[string]interface{})
	if !ok {
		t.Fatalf("expected map model, got %T", agent2.Model)
	}
	if m["primary"] != "openai/gpt-5" {
		t.Errorf("expected primary 'openai/gpt-5', got %v", m["primary"])
	}
}

func TestAgentPreservesExtraFields(t *testing.T) {
	jsonStr := `{"id":"main","name":"Claw","model":"gpt-5.4","default":true,"subagents":{"allowAgents":["builder"]},"workspace":"/test"}`
	var agent Agent
	if err := json.Unmarshal([]byte(jsonStr), &agent); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}

	if agent.ID != "main" {
		t.Errorf("expected id 'main', got %q", agent.ID)
	}

	// Check extra fields preserved
	if _, ok := agent.Extra["default"]; !ok {
		t.Error("'default' field not preserved in Extra")
	}
	if _, ok := agent.Extra["subagents"]; !ok {
		t.Error("'subagents' field not preserved in Extra")
	}

	// Re-marshal and verify
	data, err := json.Marshal(agent)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	var m map[string]interface{}
	json.Unmarshal(data, &m)

	if _, ok := m["default"]; !ok {
		t.Error("'default' field lost during marshal")
	}
	if _, ok := m["subagents"]; !ok {
		t.Error("'subagents' field lost during marshal")
	}
}

func TestBindingPreservesMatchField(t *testing.T) {
	jsonStr := `{"agentId":"builder","match":{"channel":"discord","peer":{"kind":"channel","id":"123"}}}`
	var binding Binding
	if err := json.Unmarshal([]byte(jsonStr), &binding); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}

	if binding.AgentID != "builder" {
		t.Errorf("expected agentId 'builder', got %q", binding.AgentID)
	}

	if _, ok := binding.Extra["match"]; !ok {
		t.Error("'match' field not preserved in Extra")
	}

	// Re-marshal and verify
	data, err := json.Marshal(binding)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	var m map[string]interface{}
	json.Unmarshal(data, &m)

	if _, ok := m["match"]; !ok {
		t.Error("'match' field lost during marshal")
	}
}

func TestDefaultsModelParsing(t *testing.T) {
	jsonStr := `{"agents":{"defaults":{"model":{"primary":"openai-codex/gpt-5.4","fallbacks":["anthropic/claude-sonnet-4-6"]}},"list":[]}}`

	var raw map[string]json.RawMessage
	json.Unmarshal([]byte(jsonStr), &raw)

	cfg := &OpenClawConfig{raw: raw}
	var agentsMap map[string]json.RawMessage
	json.Unmarshal(raw["agents"], &agentsMap)
	var defaultsMap map[string]json.RawMessage
	json.Unmarshal(agentsMap["defaults"], &defaultsMap)
	var model interface{}
	json.Unmarshal(defaultsMap["model"], &model)
	cfg.Agents.Defaults.Model = model

	m, ok := cfg.Agents.Defaults.Model.(map[string]interface{})
	if !ok {
		t.Fatalf("expected map default model, got %T", cfg.Agents.Defaults.Model)
	}
	if m["primary"] != "openai-codex/gpt-5.4" {
		t.Errorf("expected primary 'openai-codex/gpt-5.4', got %v", m["primary"])
	}
}

func TestUserConfigDefaults(t *testing.T) {
	cfg := &UserConfig{Fleet: make(map[string]interface{})}
	if len(cfg.Fleet) != 0 {
		t.Errorf("expected empty fleet map")
	}
	cfg.Fleet["test"] = "value"
	if cfg.Fleet["test"] != "value" {
		t.Errorf("expected 'value', got %v", cfg.Fleet["test"])
	}
}
