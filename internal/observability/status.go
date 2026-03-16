package observability

import (
	"time"

	"github.com/cyperx84/clawforge/internal/fleet"
)

// AgentStatus represents the status of an agent
type AgentStatus struct {
	ID           string
	Name         string
	Status       string
	Model        string
	Bindings     int
	MemoryFiles  int
	ReferenceFiles int
	LastActive   time.Time
}

// GetFleetStatus returns the status of all agents
func GetFleetStatus() ([]AgentStatus, error) {
	agents, err := fleet.ListAgents()
	if err != nil {
		return nil, err
	}

	var statuses []AgentStatus
	for _, agent := range agents {
		memFiles, _ := fleet.CountMemoryFiles(agent.ID)
		refFiles, _ := fleet.CountReferenceFiles(agent.ID)

		status := AgentStatus{
			ID:             agent.ID,
			Name:           agent.Name,
			Status:         agent.Status,
			Model:          fleet.ResolveModelDisplay(agent.Model),
			Bindings:       len(agent.Bindings),
			MemoryFiles:    memFiles,
			ReferenceFiles: refFiles,
			LastActive:    time.Now(),
		}
		statuses = append(statuses, status)
	}
	return statuses, nil
}

// GetAgentStatus returns the status of a specific agent
func GetAgentStatus(id string) (*AgentStatus, error) {
	agent, err := fleet.GetAgent(id)
	if err != nil {
		return nil, err
	}

	memFiles, _ := fleet.CountMemoryFiles(id)
	refFiles, _ := fleet.CountReferenceFiles(id)

	return &AgentStatus{
		ID:             agent.ID,
		Name:           agent.Name,
		Status:         agent.Status,
		Model:          fleet.ResolveModelDisplay(agent.Model),
		Bindings:       len(agent.Bindings),
		MemoryFiles:    memFiles,
		ReferenceFiles: refFiles,
		LastActive:    time.Now(),
	}, nil
}
