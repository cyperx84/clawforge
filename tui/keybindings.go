package main

import (
	"fmt"
	"os/exec"
	"strings"

	tea "charm.land/bubbletea/v2"
)

// stopDoneMsg is sent when a stop command finishes.
type stopDoneMsg struct{ err error }

// attachDoneMsg is sent when an attach (tmux) command finishes.
type attachDoneMsg struct{ err error }

// nudgeDoneMsg is sent when a nudge command finishes.
type nudgeDoneMsg struct{ err error }

// handleKeyPress dispatches key events to the appropriate handler based on
// current mode (filter, steer, or normal dashboard).
func handleKeyPress(m Model, msg tea.KeyPressMsg) (Model, tea.Cmd) {
	key := msg.String()

	// If in filter mode, delegate to filter handler.
	if m.filterMode {
		return handleFilterKey(m, key)
	}

	// If in steer mode, delegate to steer handler.
	if m.steerMode {
		return handleSteerKey(m, key)
	}

	// If confirming stop, handle y/n.
	if m.confirmStop {
		return handleConfirmStop(m, key)
	}

	// Normal dashboard mode.
	agents := m.filteredAgents()
	count := len(agents)

	switch key {
	case "q", "ctrl+c":
		return m, tea.Quit

	case "j", "down":
		if count > 0 && m.selected < count-1 {
			m.selected++
		}
		return m, nil

	case "k", "up":
		if m.selected > 0 {
			m.selected--
		}
		return m, nil

	case "g":
		m.selected = 0
		return m, nil

	case "G":
		if count > 0 {
			m.selected = count - 1
		}
		return m, nil

	case "enter":
		// Attach to selected agent's tmux session.
		if count > 0 {
			agent := agents[m.selected]
			session := agent.TmuxSession
			if session == "" {
				session = "clawforge-" + agent.ID
			}
			// Check if tmux session exists before trying to attach
			check := exec.Command("tmux", "has-session", "-t", session)
			if err := check.Run(); err != nil {
				// Session doesn't exist — show logs instead
				logCmd := exec.Command("tmux", "show-buffer", "-b", session)
				if logOut, logErr := logCmd.Output(); logErr == nil && len(logOut) > 0 {
					m.showPreview = true
					filtered := m.filteredAgents()
					if m.selected < len(filtered) {
						filtered[m.selected].Preview = string(logOut)
					}
				}
				return m, nil
			}
			cmd := exec.Command("tmux", "attach-session", "-t", session)
			return m, tea.ExecProcess(cmd, func(err error) tea.Msg {
				return attachDoneMsg{err}
			})
		}
		return m, nil

	case "s":
		// Open steer input modal.
		if count > 0 {
			m.steerMode = true
			m.steerInput = ""
		}
		return m, nil

	case "x":
		// Stop selected agent (with confirmation).
		if count > 0 {
			m.confirmStop = true
		}
		return m, nil

	case "/":
		// Open filter input.
		m.filterMode = true
		m.filter = ""
		return m, nil

	case "1":
		m.viewMode = "all"
		m.selected = 0
		return m, nil

	case "2":
		m.viewMode = "running"
		m.selected = 0
		return m, nil

	case "3":
		m.viewMode = "finished"
		m.selected = 0
		return m, nil

	case "tab":
		if m.viewMode == "all" {
			m.viewMode = "running"
		} else if m.viewMode == "running" {
			m.viewMode = "finished"
		} else {
			m.viewMode = "all"
		}
		m.selected = 0
		return m, nil

	case "r":
		// Force refresh.
		m.agents = LoadAgents()
		// Clamp selection.
		filtered := m.filteredAgents()
		if m.selected >= len(filtered) {
			m.selected = max(0, len(filtered)-1)
		}
		return m, nil

	case "p":
		m.showPreview = !m.showPreview
		return m, nil

	case "n":
		// Nudge selected running agent with a lightweight progress prompt.
		if count > 0 {
			agent := agents[m.selected]
			if agent.Status == "running" || agent.Status == "spawned" {
				cmd := exec.Command("clawforge", "steer", agent.ID, "Quick nudge: share current progress, blockers, and ETA.")
				return m, tea.ExecProcess(cmd, func(err error) tea.Msg {
					return nudgeDoneMsg{err}
				})
			}
		}
		return m, nil

	case "?":
		m.showHelp = !m.showHelp
		return m, nil

	case "esc":
		// Close any overlay.
		if m.showHelp {
			m.showHelp = false
		}
		return m, nil
	}

	return m, nil
}

// handleConfirmStop processes y/n when confirming an agent stop.
func handleConfirmStop(m Model, key string) (Model, tea.Cmd) {
	switch key {
	case "y", "Y":
		agents := m.filteredAgents()
		if len(agents) > 0 {
			agent := agents[m.selected]
			m.confirmStop = false
			cmd := exec.Command("clawforge", "stop", agent.ID, "--yes")
			return m, tea.ExecProcess(cmd, func(err error) tea.Msg {
				return stopDoneMsg{err}
			})
		}
		m.confirmStop = false
		return m, nil
	case "n", "N", "esc":
		m.confirmStop = false
		return m, nil
	}
	return m, nil
}

// renderHelpOverlay renders the keybinding help overlay.
func renderHelpOverlay(width int) string {
	bindings := []struct {
		key  string
		desc string
	}{
		{"j/k", "Navigate agent list"},
		{"Enter", "Attach to selected agent's tmux session"},
		{"s", "Steer selected agent (prompts for message)"},
		{"x", "Stop selected agent"},
		{"/", "Filter agents"},
		{"1/2/3", "Views: all / running / finished"},
		{"Tab", "Cycle views"},
		{"n", "Nudge selected running agent"},
		{"p", "Toggle output preview pane"},
		{"r", "Force refresh"},
		{"g/G", "Go to top/bottom"},
		{"?", "Toggle help overlay"},
		{"Esc", "Close modal/overlay"},
		{"q", "Quit dashboard"},
	}

	var lines []string
	lines = append(lines, headerStyle.Render("Keybindings"))
	lines = append(lines, "")

	for _, b := range bindings {
		keyStr := fmt.Sprintf("  %-10s", b.key)
		lines = append(lines, keyStr+b.desc)
	}

	content := strings.Join(lines, "\n")
	return helpOverlayStyle.Render(content)
}
