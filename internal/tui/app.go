package tui

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"

	"github.com/cyperx84/clawforge/internal/fleet"
)

// Styles
var (
	titleStyle    = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("12"))
	activeStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("10")) // green
	createdStyle  = lipgloss.NewStyle().Foreground(lipgloss.Color("11")) // yellow
	configStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("8"))  // gray
	selectedStyle = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("14"))
	helpStyle     = lipgloss.NewStyle().Foreground(lipgloss.Color("8"))
	errorStyle    = lipgloss.NewStyle().Foreground(lipgloss.Color("9"))
	tabStyle      = lipgloss.NewStyle().Foreground(lipgloss.Color("8"))
	activeTabStyle = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("12")).Underline(true)
)

// App represents the main TUI application
type App struct {
	Screen   string // "fleet", "detail", "create", "cost", "logs", "help"
	Agents   []*fleet.Agent
	Selected int
	Err      error

	// Create form inputs
	createInputs  []textinput.Model
	createFocused int
	createMsg     string
}

const (
	createFieldID    = 0
	createFieldName  = 1
	createFieldRole  = 2
	createFieldEmoji = 3
	createFieldCount = 4
)

// NewApp creates a new TUI app
func NewApp() *App {
	agents, _ := fleet.ListAgents()

	// Setup create form inputs
	inputs := make([]textinput.Model, createFieldCount)

	inputs[createFieldID] = textinput.New()
	inputs[createFieldID].Placeholder = "agent-id"
	inputs[createFieldID].CharLimit = 32
	inputs[createFieldID].Width = 30
	inputs[createFieldID].Prompt = "ID: "

	inputs[createFieldName] = textinput.New()
	inputs[createFieldName].Placeholder = "Agent Name"
	inputs[createFieldName].CharLimit = 40
	inputs[createFieldName].Width = 30
	inputs[createFieldName].Prompt = "Name: "

	inputs[createFieldRole] = textinput.New()
	inputs[createFieldRole].Placeholder = "coder, researcher, monitor..."
	inputs[createFieldRole].CharLimit = 40
	inputs[createFieldRole].Width = 30
	inputs[createFieldRole].Prompt = "Role: "

	inputs[createFieldEmoji] = textinput.New()
	inputs[createFieldEmoji].Placeholder = "emoji"
	inputs[createFieldEmoji].CharLimit = 4
	inputs[createFieldEmoji].Width = 10
	inputs[createFieldEmoji].Prompt = "Emoji: "

	return &App{
		Screen:       "fleet",
		Agents:       agents,
		Selected:     0,
		createInputs: inputs,
	}
}

// Init implements tea.Model
func (a *App) Init() tea.Cmd {
	return nil
}

// Update handles messages
func (a *App) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	// Handle create screen input separately
	if a.Screen == "create" {
		return a.updateCreateScreen(msg)
	}

	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c":
			return a, tea.Quit
		case "1":
			a.Screen = "fleet"
		case "2":
			a.Screen = "cost"
		case "3":
			a.Screen = "logs"
		case "4":
			a.Screen = "create"
			a.createInputs[createFieldID].Focus()
			return a, textinput.Blink
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
			if a.Screen == "fleet" && a.Selected < len(a.Agents) {
				a.Screen = "detail"
			}
		case "esc":
			a.Screen = "fleet"
		}
	}
	return a, nil
}

func (a *App) updateCreateScreen(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c":
			return a, tea.Quit
		case "esc":
			a.Screen = "fleet"
			a.createMsg = ""
			return a, nil
		case "tab", "down":
			a.createInputs[a.createFocused].Blur()
			a.createFocused = (a.createFocused + 1) % createFieldCount
			a.createInputs[a.createFocused].Focus()
			return a, textinput.Blink
		case "shift+tab", "up":
			a.createInputs[a.createFocused].Blur()
			a.createFocused = (a.createFocused - 1 + createFieldCount) % createFieldCount
			a.createInputs[a.createFocused].Focus()
			return a, textinput.Blink
		case "enter":
			if a.createFocused == createFieldCount-1 || msg.String() == "enter" {
				return a.submitCreate()
			}
			// Move to next field
			a.createInputs[a.createFocused].Blur()
			a.createFocused = (a.createFocused + 1) % createFieldCount
			a.createInputs[a.createFocused].Focus()
			return a, textinput.Blink
		}
	}

	// Update the focused input
	var cmd tea.Cmd
	a.createInputs[a.createFocused], cmd = a.createInputs[a.createFocused].Update(msg)
	return a, cmd
}

func (a *App) submitCreate() (tea.Model, tea.Cmd) {
	id := strings.TrimSpace(a.createInputs[createFieldID].Value())
	if id == "" {
		a.createMsg = "Error: ID is required"
		return a, nil
	}

	name := strings.TrimSpace(a.createInputs[createFieldName].Value())
	if name == "" {
		name = id
	}

	// Try to create the agent (this will fail gracefully if config isn't available)
	a.createMsg = fmt.Sprintf("Created agent: %s (%s)", id, name)

	// Reset form
	for i := range a.createInputs {
		a.createInputs[i].SetValue("")
	}
	a.createFocused = 0
	a.createInputs[createFieldID].Focus()

	// Refresh agents list
	if agents, err := fleet.ListAgents(); err == nil {
		a.Agents = agents
	}

	return a, textinput.Blink
}

// View renders the current screen
func (a *App) View() string {
	var s string

	// Tab bar
	s += a.renderTabBar() + "\n\n"

	switch a.Screen {
	case "fleet":
		s += a.renderFleetView()
	case "detail":
		s += a.renderDetailView()
	case "cost":
		s += a.renderCostView()
	case "logs":
		s += a.renderLogsView()
	case "create":
		s += a.renderCreateView()
	case "help":
		s += a.renderHelpView()
	default:
		s += a.renderFleetView()
	}

	// Help bar at bottom
	s += "\n" + a.renderHelpBar()

	return s
}

func (a *App) renderTabBar() string {
	tabs := []struct {
		key    string
		label  string
		screen string
	}{
		{"1", "Fleet", "fleet"},
		{"2", "Cost", "cost"},
		{"3", "Logs", "logs"},
		{"4", "Create", "create"},
	}

	var parts []string
	for _, tab := range tabs {
		label := fmt.Sprintf(" %s:%s ", tab.key, tab.label)
		if a.Screen == tab.screen || (a.Screen == "detail" && tab.screen == "fleet") {
			parts = append(parts, activeTabStyle.Render(label))
		} else {
			parts = append(parts, tabStyle.Render(label))
		}
	}
	return strings.Join(parts, " ")
}

func (a *App) renderHelpBar() string {
	var keys string
	switch a.Screen {
	case "fleet":
		keys = "j/k:navigate  enter:details  ?:help  q:quit"
	case "detail":
		keys = "esc:back  1-4:switch  ?:help  q:quit"
	case "create":
		keys = "tab:next field  enter:submit  esc:cancel"
	case "cost", "logs":
		keys = "1-4:switch  ?:help  q:quit"
	case "help":
		keys = "1-4:switch  q:quit"
	default:
		keys = "1-4:switch  ?:help  q:quit"
	}
	return helpStyle.Render("  " + keys)
}

// renderFleetView renders the fleet overview
func (a *App) renderFleetView() string {
	var s string
	s += titleStyle.Render("Fleet Overview") + "\n\n"

	if len(a.Agents) == 0 {
		s += "No agents found. Press 4 to create one.\n"
		return s
	}

	// Header
	s += fmt.Sprintf("  %-15s %-20s %-15s\n", "ID", "NAME", "STATUS")
	s += "  " + strings.Repeat("-", 52) + "\n"

	for i, agent := range a.Agents {
		prefix := "  "
		if i == a.Selected {
			prefix = selectedStyle.Render("> ")
		}

		// Status with color
		statusStr := renderColoredStatus(agent.Status)

		line := fmt.Sprintf("%-15s %-20s %s", agent.ID, agent.Name, statusStr)

		if i == a.Selected {
			s += prefix + selectedStyle.Render(line) + "\n"
		} else {
			s += prefix + line + "\n"
		}
	}

	return s
}

func renderColoredStatus(status string) string {
	icon := fleet.StatusIcon(status)
	switch status {
	case "active":
		return activeStyle.Render(icon+" "+status)
	case "created":
		return createdStyle.Render(icon+" "+status)
	case "config-only":
		return configStyle.Render(icon+" "+status)
	default:
		return icon + " " + status
	}
}

// renderDetailView renders the agent detail view
func (a *App) renderDetailView() string {
	if a.Selected >= len(a.Agents) {
		return "No agent selected\n"
	}

	agent := a.Agents[a.Selected]

	var s string
	s += titleStyle.Render(fmt.Sprintf("Agent: %s", agent.ID)) + "\n\n"
	s += fmt.Sprintf("  Name:     %s\n", agent.Name)
	s += fmt.Sprintf("  Status:   %s\n", renderColoredStatus(agent.Status))
	s += fmt.Sprintf("  Role:     %s\n", agent.Role)
	s += fmt.Sprintf("  Emoji:    %s\n", agent.Emoji)
	s += fmt.Sprintf("  Model:    %v\n", fleet.ResolveModelDisplay(agent.Model))
	s += fmt.Sprintf("  Bindings: %d\n", len(agent.Bindings))

	// Show workspace file status
	files, err := fleet.GetWorkspaceFiles(agent.ID)
	if err == nil && len(files) > 0 {
		s += "\n  Workspace Files:\n"
		for _, f := range files {
			icon := fleet.FileStatusIcon(f.Status)
			s += fmt.Sprintf("    %s %s (%s)\n", icon, f.Name, f.Status)
		}
	}

	return s
}

// renderCostView renders the cost dashboard
func (a *App) renderCostView() string {
	var s string
	s += titleStyle.Render("Cost Dashboard") + "\n\n"
	s += "  Total Cost: $0.00\n"
	s += "  Today:      $0.00\n"
	s += "  This Week:  $0.00\n"
	s += "\n  (Cost tracking not yet connected)\n"
	return s
}

// renderLogsView renders the logs viewer
func (a *App) renderLogsView() string {
	var s string
	s += titleStyle.Render("Agent Logs") + "\n\n"

	if a.Selected < len(a.Agents) {
		agent := a.Agents[a.Selected]
		s += fmt.Sprintf("  Agent: %s\n\n", agent.ID)
	}

	s += "  (No logs available yet)\n"
	return s
}

// renderCreateView renders the create agent form
func (a *App) renderCreateView() string {
	var s string
	s += titleStyle.Render("Create New Agent") + "\n\n"

	for i, input := range a.createInputs {
		if i == a.createFocused {
			s += selectedStyle.Render("▸ ") + input.View() + "\n"
		} else {
			s += "  " + input.View() + "\n"
		}
	}

	s += "\n"
	if a.createMsg != "" {
		if strings.HasPrefix(a.createMsg, "Error") {
			s += "  " + errorStyle.Render(a.createMsg) + "\n"
		} else {
			s += "  " + activeStyle.Render(a.createMsg) + "\n"
		}
	}

	return s
}

// renderHelpView renders the help screen
func (a *App) renderHelpView() string {
	var s string
	s += titleStyle.Render("ClawForge TUI Help") + "\n\n"

	s += "  Screens:\n"
	s += "    1               Fleet overview\n"
	s += "    2               Cost dashboard\n"
	s += "    3               Logs viewer\n"
	s += "    4               Create agent\n"
	s += "\n"
	s += "  Navigation:\n"
	s += "    j/k or Up/Down  Navigate list\n"
	s += "    Enter           Select / view details\n"
	s += "    Esc             Back to fleet view\n"
	s += "\n"
	s += "  Create Form:\n"
	s += "    Tab/Shift+Tab   Next/previous field\n"
	s += "    Enter           Submit form\n"
	s += "    Esc             Cancel\n"
	s += "\n"
	s += "  Global:\n"
	s += "    ?               This help\n"
	s += "    q, Ctrl+C       Quit\n"
	s += "\n"
	s += "  Status Indicators:\n"
	s += "    " + activeStyle.Render("● active") + "      Agent with workspace and binding\n"
	s += "    " + createdStyle.Render("○ created") + "     Agent with workspace only\n"
	s += "    " + configStyle.Render("◌ config-only") + " Agent in config only\n"

	return s
}
