package fleet

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/cyperx84/clawforge/internal/config"
)

// Agent represents an agent with full metadata
type Agent struct {
	config.Agent
	Status   string // "active", "created", "config-only"
	Bindings []config.Binding
}

// GetAgent retrieves a single agent by ID
func GetAgent(id string) (*Agent, error) {
	cfg, err := config.ReadOpenClawConfig()
	if err != nil {
		return nil, err
	}

	var agent *config.Agent
	for i := range cfg.Agents.List {
		if cfg.Agents.List[i].ID == id {
			agent = &cfg.Agents.List[i]
			break
		}
	}
	if agent == nil {
		// Try filesystem discovery
		agentsDir, adErr := config.AgentsDir()
		if adErr == nil {
			wsPath := filepath.Join(agentsDir, id)
			if _, statErr := os.Stat(filepath.Join(wsPath, "SOUL.md")); statErr == nil {
				name := id
				if soulContent, readErr := os.ReadFile(filepath.Join(wsPath, "SOUL.md")); readErr == nil {
					if extracted := extractNameFromSoul(string(soulContent)); extracted != "" {
						name = extracted
					}
				}
				agent = &config.Agent{ID: id, Name: name, Workspace: wsPath, Model: cfg.Agents.Defaults.Model}
			}
		}
		if agent == nil {
			return nil, fmt.Errorf("agent not found: %s", id)
		}
	}

	status := determineStatus(id, agent, cfg)
	bindings := getBindings(id, cfg)

	return &Agent{
		Agent:    *agent,
		Status:   status,
		Bindings: bindings,
	}, nil
}

// ListAgents retrieves all agents from config AND filesystem discovery
func ListAgents() ([]*Agent, error) {
	cfg, err := config.ReadOpenClawConfig()
	if err != nil {
		return nil, err
	}

	seen := make(map[string]bool)
	var agents []*Agent

	// 1. Agents from config
	for i := range cfg.Agents.List {
		a := cfg.Agents.List[i]
		seen[a.ID] = true
		status := determineStatus(a.ID, &a, cfg)
		bindings := getBindings(a.ID, cfg)
		agents = append(agents, &Agent{
			Agent:    a,
			Status:   status,
			Bindings: bindings,
		})
	}

	// 2. Discover agents from ~/.openclaw/agents/ directories
	agentsDir, adErr := config.AgentsDir()
	if adErr != nil {
		return agents, nil
	}
	entries, err := os.ReadDir(agentsDir)
	if err == nil {
		for _, entry := range entries {
			if !entry.IsDir() || seen[entry.Name()] {
				continue
			}
			id := entry.Name()
			wsPath := filepath.Join(agentsDir, id)

			// Must have at least SOUL.md to count as an agent
			if _, err := os.Stat(filepath.Join(wsPath, "SOUL.md")); err != nil {
				continue
			}

			// Read agent name from SOUL.md if possible
			name := id
			if soulContent, err := os.ReadFile(filepath.Join(wsPath, "SOUL.md")); err == nil {
				if extracted := extractNameFromSoul(string(soulContent)); extracted != "" {
					name = extracted
				}
			}

			seen[id] = true
			a := config.Agent{
				ID:        id,
				Name:      name,
				Workspace: wsPath,
				Model:     cfg.Agents.Defaults.Model,
			}
			status := determineStatus(id, &a, cfg)
			bindings := getBindings(id, cfg)
			agents = append(agents, &Agent{
				Agent:    a,
				Status:   status,
				Bindings: bindings,
			})
		}
	}

	return agents, nil
}

// extractNameFromSoul tries to find the agent name from SOUL.md content
func extractNameFromSoul(content string) string {
	// Look for "You are **Name**" or "# SOUL.md - Name"
	lines := splitLines(content)
	prefix := "# SOUL.md - "
	for _, line := range lines {
		// Match "# SOUL.md - Name" pattern
		if len(line) > len(prefix) && line[:len(prefix)] == prefix {
			return line[len(prefix):]
		}
		// Match "You are **Name**" pattern
		if idx := indexOf(line, "You are **"); idx >= 0 {
			rest := line[idx+10:]
			if end := indexOf(rest, "**"); end >= 0 {
				return rest[:end]
			}
		}
	}
	return ""
}

func splitLines(s string) []string {
	var lines []string
	start := 0
	for i := 0; i < len(s); i++ {
		if s[i] == '\n' {
			lines = append(lines, s[start:i])
			start = i + 1
		}
	}
	if start < len(s) {
		lines = append(lines, s[start:])
	}
	return lines
}

func indexOf(s, substr string) int {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return i
		}
	}
	return -1
}

// CreateAgent creates a new agent via the openclaw CLI (safe config writes)
func CreateAgent(agent *config.Agent) error {
	// Resolve model to string for CLI
	model := ""
	switch v := agent.Model.(type) {
	case string:
		model = v
	case map[string]interface{}:
		if p, ok := v["primary"].(string); ok {
			model = p
		}
	}

	return OpenClawAgentAdd(agent.ID, agent.Name, model, agent.Workspace)
}

// UpdateAgent updates an agent in the config via config.patch
// Uses the safe JSON-preserving write since openclaw CLI doesn't have
// a direct "update agent fields" command yet.
func UpdateAgent(agent *config.Agent) error {
	cfg, err := config.ReadOpenClawConfig()
	if err != nil {
		return err
	}

	found := false
	for i := range cfg.Agents.List {
		if cfg.Agents.List[i].ID == agent.ID {
			cfg.Agents.List[i] = *agent
			found = true
			break
		}
	}
	if !found {
		return fmt.Errorf("agent not found: %s", agent.ID)
	}

	return config.WriteOpenClawConfig(cfg)
}

// DeleteAgent removes an agent via the openclaw CLI (safe config writes)
func DeleteAgent(id string) error {
	return OpenClawAgentDelete(id)
}

// GetWorkspacePath returns the workspace path for an agent without circular dependency
func GetWorkspacePath(id string) (string, error) {
	// 1. Special case: main agent
	if id == "main" {
		u, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}
		return filepath.Join(u, ".openclaw", "workspace"), nil
	}

	// 2. New isolated path
	agentsDir, err := config.AgentsDir()
	if err != nil {
		return "", err
	}
	newPath := filepath.Join(agentsDir, id)
	if _, err := os.Stat(newPath); err == nil {
		return newPath, nil
	}

	// 3. Legacy nested path
	u, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	legacyPath := filepath.Join(u, ".openclaw", "workspace", "agents", id)
	if _, err := os.Stat(legacyPath); err == nil {
		return legacyPath, nil
	}

	// Default to new isolated path
	return newPath, nil
}

// GetWorkspace returns the workspace path for an agent
func GetWorkspace(id string) (string, error) {
	cfg, err := config.ReadOpenClawConfig()
	if err != nil {
		return "", err
	}

	// Check for explicit workspace field
	for _, a := range cfg.Agents.List {
		if a.ID == id {
			if a.Workspace != "" {
				return a.Workspace, nil
			}
			break
		}
	}

	// Use default resolution
	return GetWorkspacePath(id)
}

// determineStatus checks if an agent is active, created, or config-only
func determineStatus(id string, agent *config.Agent, cfg *config.OpenClawConfig) string {
	workspace, err := GetWorkspacePath(id)
	if err != nil {
		return "unknown"
	}

	inConfig := true
	hasWorkspace := false
	hasBinding := false

	if cfg != nil {
		hasBinding = false
		for _, b := range cfg.Bindings {
			if b.AgentID == id {
				hasBinding = true
				break
			}
		}
	}

	if _, err := os.Stat(workspace); err == nil {
		hasWorkspace = true
	}

	if inConfig && hasWorkspace && hasBinding {
		return "active"
	} else if hasWorkspace {
		return "created"
	} else if inConfig {
		return "config-only"
	}
	return "unknown"
}

// ResolveModelDisplay converts a model value (string, map, or nil) to a display string
func ResolveModelDisplay(model interface{}) string {
	switch v := model.(type) {
	case string:
		if v == "" {
			return "default"
		}
		return parseModelString(v)
	case map[string]interface{}:
		if primary, ok := v["primary"].(string); ok {
			return parseModelString(primary)
		}
	}
	return "default"
}

// parseModelString extracts model name from "provider/model" format
func parseModelString(model string) string {
	for i := len(model) - 1; i >= 0; i-- {
		if model[i] == '/' {
			return model[i+1:]
		}
	}
	return model
}

// getBindings returns all bindings for an agent
func getBindings(id string, cfg *config.OpenClawConfig) []config.Binding {
	var bindings []config.Binding
	for _, b := range cfg.Bindings {
		if b.AgentID == id {
			bindings = append(bindings, b)
		}
	}
	return bindings
}
