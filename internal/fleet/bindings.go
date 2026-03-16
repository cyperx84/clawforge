package fleet

import (
	"fmt"

	"github.com/cyperx84/clawforge/internal/config"
)

// GetBindings returns all bindings for an agent (read-only, safe)
func GetBindings(id string) ([]config.Binding, error) {
	cfg, err := config.ReadOpenClawConfig()
	if err != nil {
		return nil, err
	}

	var bindings []config.Binding
	for _, b := range cfg.Bindings {
		if b.AgentID == id {
			bindings = append(bindings, b)
		}
	}
	return bindings, nil
}

// AddBinding adds a new binding for an agent via the openclaw CLI
func AddBinding(agentID string, channel string) error {
	// Verify agent exists first
	cfg, err := config.ReadOpenClawConfig()
	if err != nil {
		return err
	}

	found := false
	for _, a := range cfg.Agents.List {
		if a.ID == agentID {
			found = true
			break
		}
	}
	if !found {
		return fmt.Errorf("agent not found: %s", agentID)
	}

	return OpenClawAgentBind(agentID, channel)
}

// RemoveBinding removes bindings for an agent via the openclaw CLI
func RemoveBinding(agentID string) error {
	return OpenClawAgentUnbind(agentID)
}

// BindDiscord binds an agent to a Discord channel via the openclaw CLI
func BindDiscord(agentID, channelID, serverID string) error {
	// openclaw agents bind --agent <id> --bind discord
	// The openclaw CLI handles channel resolution
	return OpenClawAgentBind(agentID, "discord")
}

// BindSlack binds an agent to a Slack channel via the openclaw CLI
func BindSlack(agentID, channelID, workspaceID string) error {
	return OpenClawAgentBind(agentID, "slack")
}
