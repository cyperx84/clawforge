package observability

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/cyperx84/clawforge/internal/config"
	"github.com/cyperx84/clawforge/internal/fleet"
)

// AgentHealth represents the health of an agent
type AgentHealth struct {
	ID           string    `json:"id"`
	Name         string    `json:"name"`
	Status       string    `json:"status"`
	LastActive   string    `json:"last_active"`
	SessionCount int       `json:"session_count"`
	HasErrors    bool      `json:"has_errors"`
	ErrorHint    string    `json:"error_hint,omitempty"`
	Healthy      bool      `json:"healthy"`
	CheckedAt    time.Time `json:"checked_at"`
}

// GetAgentHealth returns health info for a single agent
func GetAgentHealth(id string) (*AgentHealth, error) {
	agent, err := fleet.GetAgent(id)
	if err != nil {
		return nil, err
	}

	return buildHealth(agent)
}

// GetFleetHealth returns health info for all agents
func GetFleetHealth() ([]AgentHealth, error) {
	agents, err := fleet.ListAgents()
	if err != nil {
		return nil, err
	}

	var healths []AgentHealth
	for _, agent := range agents {
		h, err := buildHealth(agent)
		if err != nil {
			continue
		}
		healths = append(healths, *h)
	}
	return healths, nil
}

func buildHealth(agent *fleet.Agent) (*AgentHealth, error) {
	h := &AgentHealth{
		ID:        agent.ID,
		Name:      agent.Name,
		Status:    agent.Status,
		Healthy:   true,
		CheckedAt: time.Now(),
	}

	// Read HEARTBEAT.md for last active and error indicators
	heartbeat, err := fleet.ReadWorkspaceFile(agent.ID, "HEARTBEAT.md")
	if err == nil {
		h.LastActive = parseHeartbeatField(heartbeat, "Last Active")
		if h.LastActive == "" {
			h.LastActive = parseHeartbeatField(heartbeat, "Last Check")
		}

		// Check for error indicators
		lower := strings.ToLower(heartbeat)
		if strings.Contains(lower, "error") || strings.Contains(lower, "fail") || strings.Contains(lower, "crash") {
			h.HasErrors = true
			h.Healthy = false
			h.ErrorHint = "Error indicators found in HEARTBEAT.md"
		}
	} else {
		h.LastActive = "unknown"
	}

	// Count sessions
	h.SessionCount = countSessions(agent.ID)

	// Agent with no workspace is unhealthy
	if agent.Status == "config-only" {
		h.Healthy = false
	}

	return h, nil
}

func parseHeartbeatField(content, field string) string {
	lines := strings.Split(content, "\n")
	prefix := "**" + field + "**:"
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, prefix) {
			val := strings.TrimSpace(line[len(prefix):])
			val = strings.Trim(val, " *")
			return val
		}
	}
	return ""
}

func countSessions(id string) int {
	// Check ~/.openclaw/sessions/<id>/ first
	home, err := os.UserHomeDir()
	if err != nil {
		return 0
	}

	count := 0

	sessionsDir := filepath.Join(home, ".openclaw", "sessions", id)
	if entries, err := os.ReadDir(sessionsDir); err == nil {
		count += len(entries)
	}

	// Also check agent workspace sessions
	agentsDir, err := config.AgentsDir()
	if err != nil {
		return count
	}
	agentSessions := filepath.Join(agentsDir, id, "sessions")
	if entries, err := os.ReadDir(agentSessions); err == nil {
		count += len(entries)
	}

	return count
}

// FormatHealth returns human-readable health output
func FormatHealth(healths []AgentHealth) string {
	if len(healths) == 0 {
		return "No agents found.\n"
	}

	var s string
	s += fmt.Sprintf("%-15s %-20s %-12s %-20s %-10s %-8s\n",
		"ID", "NAME", "STATUS", "LAST ACTIVE", "SESSIONS", "HEALTH")
	s += strings.Repeat("-", 90) + "\n"

	for _, h := range healths {
		healthIcon := "ok"
		if !h.Healthy {
			healthIcon = "warn"
		}
		if h.HasErrors {
			healthIcon = "error"
		}

		lastActive := h.LastActive
		if len(lastActive) > 20 {
			lastActive = lastActive[:17] + "..."
		}

		s += fmt.Sprintf("%-15s %-20s %-12s %-20s %-10d %-8s\n",
			h.ID, h.Name, h.Status, lastActive, h.SessionCount, healthIcon)
	}
	return s
}

// FormatHealthJSON returns JSON health output
func FormatHealthJSON(healths []AgentHealth) (string, error) {
	data, err := json.MarshalIndent(healths, "", "  ")
	if err != nil {
		return "", err
	}
	return string(data), nil
}
