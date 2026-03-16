package fleet

import (
	"fmt"

	"github.com/cyperx84/clawforge/internal/config"
)

// GetBindings returns all bindings for an agent
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

// AddBinding adds a new binding for an agent
func AddBinding(agentID string, binding config.Binding) error {
	cfg, err := config.ReadOpenClawConfig()
	if err != nil {
		return err
	}

	// Check agent exists
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

	binding.AgentID = agentID
	cfg.Bindings = append(cfg.Bindings, binding)
	return config.WriteOpenClawConfig(cfg)
}

// RemoveBinding removes a binding for an agent
func RemoveBinding(agentID string) error {
	cfg, err := config.ReadOpenClawConfig()
	if err != nil {
		return err
	}

	newBindings := []config.Binding{}
	removed := false
	for _, b := range cfg.Bindings {
		if b.AgentID != agentID {
			newBindings = append(newBindings, b)
		} else {
			removed = true
		}
	}

	if !removed {
		return fmt.Errorf("no binding found for agent: %s", agentID)
	}

	cfg.Bindings = newBindings
	return config.WriteOpenClawConfig(cfg)
}

// BindDiscord binds an agent to a Discord channel
func BindDiscord(agentID, channelID, serverID string) error {
	binding := config.Binding{
		AgentID: agentID,
		Discord: &config.Discord{
			ChannelID: channelID,
			ServerID:  serverID,
		},
	}
	return AddBinding(agentID, binding)
}

// BindSlack binds an agent to a Slack channel
func BindSlack(agentID, channelID, workspaceID string) error {
	binding := config.Binding{
		AgentID: agentID,
		Slack: &config.Slack{
			ChannelID:   channelID,
			WorkspaceID: workspaceID,
		},
	}
	return AddBinding(agentID, binding)
}
