package config

import (
	"encoding/json"
	"fmt"
	"os"
	"os/user"
	"path/filepath"
)

// OpenClawConfig represents the ~/.openclaw/openclaw.json structure
type OpenClawConfig struct {
	Agents struct {
		Defaults struct {
			Model interface{} `json:"model"`
		} `json:"defaults"`
		List []Agent `json:"list"`
	} `json:"agents"`
	Bindings []Binding `json:"bindings"`
}

// Agent represents an agent in the OpenClaw config
type Agent struct {
	ID        string      `json:"id"`
	Name      string      `json:"name,omitempty"`
	Model     interface{} `json:"model"` // can be string or {primary, fallbacks}
	Workspace string      `json:"workspace,omitempty"`
	Role      string      `json:"role,omitempty"`
	Emoji     string      `json:"emoji,omitempty"`
}

// Binding represents a channel binding for an agent
type Binding struct {
	AgentID string      `json:"agentId"`
	Discord *Discord    `json:"discord,omitempty"`
	Slack   *Slack      `json:"slack,omitempty"`
}

// Discord represents a Discord binding
type Discord struct {
	ChannelID string `json:"channelId"`
	ServerID  string `json:"serverId,omitempty"`
}

// Slack represents a Slack binding
type Slack struct {
	ChannelID string `json:"channelId"`
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

// ReadOpenClawConfig reads the OpenClaw configuration
func ReadOpenClawConfig() (*OpenClawConfig, error) {
	path, err := OpenClawConfigPath()
	if err != nil {
		return nil, err
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read OpenClaw config: %w", err)
	}
	var cfg OpenClawConfig
	if err := json.Unmarshal(data, &cfg); err != nil {
		return nil, fmt.Errorf("failed to parse OpenClaw config: %w", err)
	}
	return &cfg, nil
}

// WriteOpenClawConfig writes the OpenClaw configuration
func WriteOpenClawConfig(cfg *OpenClawConfig) error {
	path, err := OpenClawConfigPath()
	if err != nil {
		return err
	}
	// Backup
	if _, err := os.Stat(path); err == nil {
		backupPath := path + ".bak"
		data, _ := os.ReadFile(path)
		os.WriteFile(backupPath, data, 0644)
	}
	data, err := json.MarshalIndent(cfg, "", "  ")
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
