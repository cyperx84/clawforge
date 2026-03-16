package tui

import (
	"fmt"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"

	"github.com/cyperx84/clawforge/internal/fleet"
)

// App represents the main TUI application
type App struct {
	Screen   string // "fleet", "detail", "create", "cost", "logs"
	Agents   []*fleet.Agent
	Selected int
	Err      error
}

// NewApp creates a new TUI app
func NewApp() *App {
	agents, _ := fleet.ListAgents()
	return &App{
		Screen:  "fleet",
		Agents:  agents,
		Selected: 0,
	}
}

// Model implements tea.Model
func (a *App) Init() tea.Cmd {
	return nil
}

// Update handles messages
func (a *App) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c":
			return a, tea.Quit
		case "1":
			a.Screen = "fleet"
		case "2":
			a.Screen = "detail"
		case "3":
			a.Screen = "cost"
		case "4":
			a.Screen = "logs"
		case "?":
			a.Screen = "help"
		case "up", "k":
			if a.Selected > 0 {
				a.Selected--
			}
		case "down", "j":
			if a.Selected < len(a.Agents)-1 {
				a.Selected++
			}
		case "enter":
			if a.Selected < len(a.Agents) {
				a.Screen = "detail"
			}
		}
	}
	return a, nil
}

// View renders the current screen
func (a *App) View() string {
	switch a.Screen {
	case "fleet":
		return a.renderFleetView()
	case "detail":
		return a.renderDetailView()
	case "cost":
		return a.renderCostView()
	case "logs":
		return a.renderLogsView()
	case "help":
		return a.renderHelpView()
	default:
		return a.renderFleetView()
	}
}

// renderFleetView renders the fleet overview
func (a *App) renderFleetView() string {
	var s string
	s += "Fleet Overview\n\n"

	if len(a.Agents) == 0 {
		s += "No agents found. Create one with: clawforge create <id>\n"
		return s
	}

	for i, agent := range a.Agents {
		prefix := "  "
		if i == a.Selected {
			prefix = "> "
		}

		status := fleet.StatusIcon(agent.Status) + " " + agent.Status
		model := fleet.ResolveModelDisplay(agent.Model)
		if len(model) > 20 {
			model = model[:17] + "..."
		}

		line := fmt.Sprintf("%s%-15s %-20s %-15s\n",
			prefix, agent.ID, agent.Name, status)
		s += line
	}

	s += "\nKeybindings:\n"
	s += "  j/k or ↑/↓  - Navigate\n"
	s += "  Enter       - View details\n"
	s += "  c           - Create agent\n"
	s += "  d           - Delete agent\n"
	s += "  q           - Quit\n"
	s += "  ?           - Help\n"

	return s
}

// renderDetailView renders the agent detail view
func (a *App) renderDetailView() string {
	if a.Selected >= len(a.Agents) {
		return "No agent selected\n"
	}

	agent := a.Agents[a.Selected]
	style := lipgloss.NewStyle().Foreground(lipgloss.Color("12"))

	var s string
	s += style.Render(fmt.Sprintf("Agent: %s\n", agent.ID))
	s += fmt.Sprintf("Name: %s\n", agent.Name)
	s += fmt.Sprintf("Status: %s\n", fleet.StatusIcon(agent.Status)+" "+agent.Status)
	s += fmt.Sprintf("Role: %s\n", agent.Role)
	s += fmt.Sprintf("Model: %v\n", agent.Model)
	s += fmt.Sprintf("Bindings: %d\n", len(agent.Bindings))

	s += "\nKeybindings:\n"
	s += "  e           - Edit files\n"
	s += "  b           - Bind to channel\n"
	s += "  a           - Activate\n"
	s += "  Esc         - Back\n"

	return s
}

// renderCostView renders the cost dashboard
func (a *App) renderCostView() string {
	var s string
	s += "Cost Dashboard\n\n"
	s += "Total Cost: $0.00\n"
	s += "Today: $0.00\n"
	s += "This Week: $0.00\n"

	return s
}

// renderLogsView renders the logs viewer
func (a *App) renderLogsView() string {
	var s string
	s += "Agent Logs\n\n"
	s += "(No logs available yet)\n"

	return s
}

// renderHelpView renders the help screen
func (a *App) renderHelpView() string {
	var s string
	s += "ClawForge TUI Help\n\n"
	s += "Navigation:\n"
	s += "  1               - Fleet overview\n"
	s += "  2               - Agent details\n"
	s += "  3               - Cost dashboard\n"
	s += "  4               - Logs viewer\n"
	s += "  j/k or ↑/↓      - Navigate\n"
	s += "  Enter           - Select\n"
	s += "\nGlobal:\n"
	s += "  q, Ctrl+C       - Quit\n"
	s += "  ?               - This help\n"

	return s
}
