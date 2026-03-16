package config

import (
	"encoding/json"
	"fmt"
	"os"
	"os/user"
	"path/filepath"
)

// OpenClawConfig represents the ~/.openclaw/openclaw.json structure.
// It preserves ALL fields in the config file, only parsing agents and bindings
// into typed structs. Unknown fields are kept as raw JSON and written back intact.
type OpenClawConfig struct {
	// Parsed fields — what ClawForge actually works with
	Agents struct {
		Defaults struct {
			Model interface{} `json:"model"`
			// Preserve all other defaults fields
			Extra map[string]json.RawMessage `json:"-"`
		} `json:"defaults"`
		List []Agent `json:"list"`
		// Preserve all other agents fields
		Extra map[string]json.RawMessage `json:"-"`
	} `json:"agents"`
	Bindings []Binding `json:"bindings"`

	// raw holds the complete original JSON so we can merge back on write
	raw map[string]json.RawMessage
}

// Agent represents an agent in the OpenClaw config
type Agent struct {
	ID        string      `json:"id"`
	Name      string      `json:"name,omitempty"`
	Model     interface{} `json:"model"` // can be string or {primary, fallbacks}
	Workspace string      `json:"workspace,omitempty"`
	Role      string      `json:"role,omitempty"`
	Emoji     string      `json:"emoji,omitempty"`
	// Preserve all other agent fields (subagents, default, etc.)
	Extra map[string]json.RawMessage `json:"-"`
}

// Custom JSON marshaling for Agent to preserve unknown fields
func (a Agent) MarshalJSON() ([]byte, error) {
	// Start with extra fields
	m := make(map[string]interface{})
	for k, v := range a.Extra {
		m[k] = v
	}
	// Overlay known fields
	m["id"] = a.ID
	if a.Name != "" {
		m["name"] = a.Name
	}
	if a.Model != nil {
		m["model"] = a.Model
	}
	if a.Workspace != "" {
		m["workspace"] = a.Workspace
	}
	if a.Role != "" {
		m["role"] = a.Role
	}
	if a.Emoji != "" {
		m["emoji"] = a.Emoji
	}
	return json.Marshal(m)
}

// Custom JSON unmarshaling for Agent to capture unknown fields
func (a *Agent) UnmarshalJSON(data []byte) error {
	// First unmarshal everything into a raw map
	var raw map[string]json.RawMessage
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}

	// Extract known fields
	knownFields := map[string]bool{
		"id": true, "name": true, "model": true,
		"workspace": true, "role": true, "emoji": true,
	}

	if v, ok := raw["id"]; ok {
		json.Unmarshal(v, &a.ID)
	}
	if v, ok := raw["name"]; ok {
		json.Unmarshal(v, &a.Name)
	}
	if v, ok := raw["model"]; ok {
		var model interface{}
		json.Unmarshal(v, &model)
		a.Model = model
	}
	if v, ok := raw["workspace"]; ok {
		json.Unmarshal(v, &a.Workspace)
	}
	if v, ok := raw["role"]; ok {
		json.Unmarshal(v, &a.Role)
	}
	if v, ok := raw["emoji"]; ok {
		json.Unmarshal(v, &a.Emoji)
	}

	// Store unknown fields
	a.Extra = make(map[string]json.RawMessage)
	for k, v := range raw {
		if !knownFields[k] {
			a.Extra[k] = v
		}
	}

	return nil
}

// Binding represents a channel binding for an agent
type Binding struct {
	AgentID string `json:"agentId"`
	// Preserve ALL other binding fields (match, discord, slack, etc.)
	Extra map[string]json.RawMessage `json:"-"`
}

// Custom JSON marshaling for Binding to preserve unknown fields
func (b Binding) MarshalJSON() ([]byte, error) {
	m := make(map[string]interface{})
	for k, v := range b.Extra {
		m[k] = v
	}
	m["agentId"] = b.AgentID
	return json.Marshal(m)
}

// Custom JSON unmarshaling for Binding to capture unknown fields
func (b *Binding) UnmarshalJSON(data []byte) error {
	var raw map[string]json.RawMessage
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	if v, ok := raw["agentId"]; ok {
		json.Unmarshal(v, &b.AgentID)
	}
	b.Extra = make(map[string]json.RawMessage)
	for k, v := range raw {
		if k != "agentId" {
			b.Extra[k] = v
		}
	}
	return nil
}

// Discord represents a Discord binding (kept for backward compat but bindings
// now preserve all fields via Extra)
type Discord struct {
	ChannelID string `json:"channelId"`
	ServerID  string `json:"serverId,omitempty"`
}

// Slack represents a Slack binding
type Slack struct {
	ChannelID   string `json:"channelId"`
	WorkspaceID string `json:"workspaceId,omitempty"`
}

// UserConfig represents the ~/.clawforge/config.json structure
type UserConfig struct {
	Fleet map[string]interface{} `json:"fleet,omitempty"`
}

// Paths
func OpenClawConfigPath() (string, error) {
	u, err := user.Current()
	if err != nil {
		return "", err
	}
	return filepath.Join(u.HomeDir, ".openclaw", "openclaw.json"), nil
}

func AgentsDir() (string, error) {
	u, err := user.Current()
	if err != nil {
		return "", err
	}
	return filepath.Join(u.HomeDir, ".openclaw", "agents"), nil
}

func UserConfigPath() (string, error) {
	u, err := user.Current()
	if err != nil {
		return "", err
	}
	return filepath.Join(u.HomeDir, ".clawforge", "config.json"), nil
}

// ReadOpenClawConfig reads the OpenClaw configuration, preserving all fields
func ReadOpenClawConfig() (*OpenClawConfig, error) {
	path, err := OpenClawConfigPath()
	if err != nil {
		return nil, err
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read OpenClaw config: %w", err)
	}

	// First, capture the entire JSON as raw
	var raw map[string]json.RawMessage
	if err := json.Unmarshal(data, &raw); err != nil {
		return nil, fmt.Errorf("failed to parse OpenClaw config: %w", err)
	}

	cfg := &OpenClawConfig{raw: raw}

	// Parse agents section
	if agentsRaw, ok := raw["agents"]; ok {
		var agentsMap map[string]json.RawMessage
		if err := json.Unmarshal(agentsRaw, &agentsMap); err != nil {
			return nil, fmt.Errorf("failed to parse agents: %w", err)
		}

		// Parse agents.defaults
		if defaultsRaw, ok := agentsMap["defaults"]; ok {
			var defaultsMap map[string]json.RawMessage
			if err := json.Unmarshal(defaultsRaw, &defaultsMap); err != nil {
				return nil, fmt.Errorf("failed to parse agents.defaults: %w", err)
			}
			if modelRaw, ok := defaultsMap["model"]; ok {
				var model interface{}
				json.Unmarshal(modelRaw, &model)
				cfg.Agents.Defaults.Model = model
			}
			// Store extra defaults fields
			cfg.Agents.Defaults.Extra = make(map[string]json.RawMessage)
			for k, v := range defaultsMap {
				if k != "model" {
					cfg.Agents.Defaults.Extra[k] = v
				}
			}
		}

		// Parse agents.list
		if listRaw, ok := agentsMap["list"]; ok {
			if err := json.Unmarshal(listRaw, &cfg.Agents.List); err != nil {
				return nil, fmt.Errorf("failed to parse agents.list: %w", err)
			}
		}

		// Store extra agents fields
		cfg.Agents.Extra = make(map[string]json.RawMessage)
		for k, v := range agentsMap {
			if k != "defaults" && k != "list" {
				cfg.Agents.Extra[k] = v
			}
		}
	}

	// Parse bindings
	if bindingsRaw, ok := raw["bindings"]; ok {
		if err := json.Unmarshal(bindingsRaw, &cfg.Bindings); err != nil {
			return nil, fmt.Errorf("failed to parse bindings: %w", err)
		}
	}

	return cfg, nil
}

// WriteOpenClawConfig writes the OpenClaw configuration, preserving all
// fields that ClawForge doesn't manage.
func WriteOpenClawConfig(cfg *OpenClawConfig) error {
	path, err := OpenClawConfigPath()
	if err != nil {
		return err
	}

	// Backup existing config
	if _, err := os.Stat(path); err == nil {
		backupPath := path + ".bak"
		data, _ := os.ReadFile(path)
		os.WriteFile(backupPath, data, 0644)
	}

	// Start with the original raw JSON (preserves everything)
	output := make(map[string]json.RawMessage)
	for k, v := range cfg.raw {
		output[k] = v
	}

	// Rebuild agents section, preserving extra fields
	agentsMap := make(map[string]json.RawMessage)
	for k, v := range cfg.Agents.Extra {
		agentsMap[k] = v
	}

	// Rebuild agents.defaults, preserving extra fields
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

	// Marshal agents.list
	listJSON, _ := json.Marshal(cfg.Agents.List)
	agentsMap["list"] = listJSON

	agentsJSON, _ := json.Marshal(agentsMap)
	output["agents"] = agentsJSON

	// Marshal bindings
	bindingsJSON, _ := json.Marshal(cfg.Bindings)
	output["bindings"] = bindingsJSON

	data, err := json.MarshalIndent(output, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0644)
}

// ReadUserConfig reads the user configuration
func ReadUserConfig() (*UserConfig, error) {
	path, err := UserConfigPath()
	if err != nil {
		return nil, err
	}
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return &UserConfig{Fleet: make(map[string]interface{})}, nil
		}
		return nil, err
	}
	var cfg UserConfig
	if err := json.Unmarshal(data, &cfg); err != nil {
		return nil, fmt.Errorf("failed to parse user config: %w", err)
	}
	return &cfg, nil
}

// WriteUserConfig writes the user configuration
func WriteUserConfig(cfg *UserConfig) error {
	path, err := UserConfigPath()
	if err != nil {
		return err
	}
	os.MkdirAll(filepath.Dir(path), 0755)
	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0644)
}
