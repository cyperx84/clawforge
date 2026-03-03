package main

import (
	"time"

	tea "charm.land/bubbletea/v2"
)

// RefreshTickMsg triggers periodic data reload.
type RefreshTickMsg time.Time

const refreshInterval = 2 * time.Second

// Model is the top-level Bubble Tea model for the ClawForge TUI dashboard.
type Model struct {
	agents      []Agent
	selected    int
	filter      string
	filterMode  bool
	viewMode    string // all | running | finished
	showHelp    bool
	animating   bool
	width       int
	height      int
	steerMode   bool
	showPreview bool
	steerInput  string
	confirmStop bool
	frame       int
	noAnim      bool
}

// filteredAgents returns the agents matching the current filter.
func (m Model) filteredAgents() []Agent {
	agents := m.agents
	switch m.viewMode {
	case "running":
		var tmp []Agent
		for _, a := range agents {
			if a.Status == "running" || a.Status == "spawned" {
				tmp = append(tmp, a)
			}
		}
		agents = tmp
	case "finished":
		var tmp []Agent
		for _, a := range agents {
			if a.Status == "done" || a.Status == "archived" || a.Status == "failed" || a.Status == "cancelled" || a.Status == "timeout" {
				tmp = append(tmp, a)
			}
		}
		agents = tmp
	}
	return FilterAgents(agents, m.filter)
}

// NewModel creates a new Model. If noAnim is true, the startup animation is skipped.
func NewModel(noAnim bool) Model {
	return Model{
		animating: !noAnim,
		noAnim:    noAnim,
		viewMode:  "all",
	}
}

// Init starts the animation tick (or loads agents directly) and kicks off refresh.
func (m Model) Init() tea.Cmd {
	if m.animating {
		return animationTick()
	}
	// No animation: load agents immediately and start refresh cycle.
	m.agents = LoadAgents()
	return refreshTick()
}

// refreshTick returns a command that sends a RefreshTickMsg after refreshInterval.
func refreshTick() tea.Cmd {
	return tea.Tick(refreshInterval, func(t time.Time) tea.Msg {
		return RefreshTickMsg(t)
	})
}

// Update handles all incoming messages and dispatches to the appropriate handler.
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		return m, nil

	case AnimationTickMsg:
		if m.animating {
			m.frame++
			if m.frame >= len(forgeFrames) {
				m.animating = false
				m.agents = LoadAgents()
				return m, refreshTick()
			}
			return m, animationTick()
		}
		return m, nil

	case AnimationDoneMsg:
		// Animation was skipped via keypress — load agents and start refresh.
		m.agents = LoadAgents()
		return m, refreshTick()

	case RefreshTickMsg:
		if !m.animating {
			m.agents = LoadAgents()
			// Clamp selection after refresh.
			filtered := m.filteredAgents()
			if m.selected >= len(filtered) && len(filtered) > 0 {
				m.selected = len(filtered) - 1
			}
		}
		return m, refreshTick()

	case steerDoneMsg:
		// Steer command finished — refresh data.
		m.agents = LoadAgents()
		return m, nil

	case stopDoneMsg:
		// Stop command finished — refresh data.
		m.agents = LoadAgents()
		return m, nil

	case attachDoneMsg:
		// Returned from tmux attach — refresh data.
		m.agents = LoadAgents()
		return m, nil

	case nudgeDoneMsg:
		// Nudge command finished — refresh data.
		m.agents = LoadAgents()
		return m, nil

	case tea.KeyPressMsg:
		if m.animating {
			// Skip animation on any key press.
			m.animating = false
			m.frame = 0
			return m, func() tea.Msg { return AnimationDoneMsg{} }
		}
		var cmd tea.Cmd
		m, cmd = handleKeyPress(m, msg)
		return m, cmd
	}

	return m, nil
}

// View renders either the animation or the dashboard based on current state.
func (m Model) View() tea.View {
	var content string
	if m.animating {
		content = renderAnimation(m.frame, m.width, m.height)
	} else {
		content = renderDashboard(m)
	}

	v := tea.NewView(content)
	v.AltScreen = true
	return v
}
