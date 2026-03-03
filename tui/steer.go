package main

import (
	"fmt"
	"os/exec"

	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
)

// steerDoneMsg is sent when the steer command finishes.
type steerDoneMsg struct{ err error }

// handleSteerKey processes key input while in steer mode.
func handleSteerKey(m Model, key string) (Model, tea.Cmd) {
	switch key {
	case "esc":
		m.steerMode = false
		m.steerInput = ""
		return m, nil
	case "enter":
		if m.steerInput != "" {
			agents := m.filteredAgents()
			if len(agents) > 0 {
				agent := agents[m.selected]
				msg := m.steerInput
				m.steerMode = false
				m.steerInput = ""
				cmd := exec.Command("clawforge", "steer", agent.ID, msg)
				return m, tea.ExecProcess(cmd, func(err error) tea.Msg {
					return steerDoneMsg{err}
				})
			}
		}
		m.steerMode = false
		m.steerInput = ""
		return m, nil
	case "backspace":
		if len(m.steerInput) > 0 {
			m.steerInput = m.steerInput[:len(m.steerInput)-1]
		}
		return m, nil
	default:
		// Only append printable single characters.
		if len(key) == 1 {
			m.steerInput += key
		} else if key == "space" {
			m.steerInput += " "
		}
		return m, nil
	}
}

// RenderSteerInput renders the steer prompt line at the bottom of the screen.
func RenderSteerInput(m Model) string {
	agents := m.filteredAgents()
	id := "?"
	if len(agents) > 0 && m.selected < len(agents) {
		id = agents[m.selected].ID
	}

	prompt := fmt.Sprintf("⚒️  Steer agent #%s: %s", id, m.steerInput)
	cursor := "█"

	return lipgloss.NewStyle().
		Foreground(lipgloss.Color("#FF8C00")).
		Bold(true).
		Render(prompt + cursor)
}
