package main

import (
	"fmt"
	"os"
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
			m.previewContent = "" // clear static preview on navigation
		}
		return m, nil

	case "k", "up":
		if m.selected > 0 {
			m.selected--
			m.previewContent = "" // clear static preview on navigation
		}
		return m, nil

	case "g":
		m.selected = 0
		m.previewContent = ""
		return m, nil

	case "G":
		if count > 0 {
			m.selected = count - 1
			m.previewContent = ""
		}
		return m, nil

	case "enter":
		// Attach to selected agent's tmux session.
		// If no live session, fall back to showing log in preview.
		if count > 0 {
			agent := agents[m.selected]
			session := agent.TmuxSession
			if session == "" {
				session = "clawforge-" + agent.ID
			}
			// Check if tmux session exists before trying to attach.
			check := exec.Command("tmux", "has-session", "-t", session)
			if err := check.Run(); err != nil {
				// No live session — show log file in preview instead.
				m.showPreview = true
				if agent.LogPath != "" {
					if data, rerr := os.ReadFile(agent.LogPath); rerr == nil && len(data) > 0 {
						m.previewContent = "(log)\n" + tailLines(string(data), 40)
					} else {
						m.previewContent = "(no log captured — session has ended)"
					}
				} else {
					m.previewContent = "(no live session and no log path recorded)"
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
		m.previewContent = ""
		// Clamp selection.
		filtered := m.filteredAgents()
		if m.selected >= len(filtered) {
			m.selected = max(0, len(filtered)-1)
		}
		return m, nil

	case "l":
		// Show last 50 lines of agent log in preview pane.
		if count > 0 {
			agent := agents[m.selected]
			m.showPreview = true
			if agent.LogPath != "" {
				if data, err := os.ReadFile(agent.LogPath); err == nil && len(data) > 0 {
					m.previewContent = "(log) " + agent.ID + "\n" + tailLines(string(data), 50)
				} else {
					m.previewContent = "(no log yet for " + agent.ID + ")"
				}
			} else if agent.TmuxSession != "" {
				// Fallback: capture from live tmux pane.
				out, err := exec.Command("tmux", "capture-pane", "-t", agent.TmuxSession, "-p", "-S", "-50").Output()
				if err == nil && len(out) > 0 {
					m.previewContent = "(tmux) " + agent.ID + "\n" + string(out)
				} else {
					m.previewContent = "(no output captured for " + agent.ID + ")"
				}
			} else {
				m.previewContent = "(no log path or tmux session for " + agent.ID + ")"
			}
		}
		return m, nil

	case "d":
		// Show git diff --stat for selected agent's worktree.
		if count > 0 {
			agent := agents[m.selected]
			m.showPreview = true
			if agent.Worktree != "" {
				out, err := exec.Command("git", "-C", agent.Worktree, "diff", "--stat", "HEAD").Output()
				if err == nil && len(out) > 0 {
					m.previewContent = "(diff) " + agent.ID + "\n" + string(out)
				} else {
					out2, _ := exec.Command("git", "-C", agent.Worktree, "status", "--short").Output()
					m.previewContent = "(diff) " + agent.ID + " — no diff yet\n" + string(out2)
				}
			} else {
				m.previewContent = "(no worktree recorded for " + agent.ID + ")"
			}
		}
		return m, nil

	case "p":
		// Toggle live preview pane (clears any static log/diff content).
		m.showPreview = !m.showPreview
		if !m.showPreview {
			m.previewContent = ""
		}
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
		if m.previewContent != "" {
			m.previewContent = ""
			m.showPreview = false
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
		{"Enter", "Attach to tmux session (or show log if session gone)"},
		{"l", "Show agent log in preview pane"},
		{"d", "Show git diff in preview pane"},
		{"s", "Steer selected agent (prompts for message)"},
		{"x", "Stop selected agent"},
		{"/", "Filter agents"},
		{"1/2/3", "Views: all / running / finished"},
		{"Tab", "Cycle views"},
		{"n", "Nudge selected running agent"},
		{"p", "Toggle live output preview pane"},
		{"r", "Force refresh"},
		{"g/G", "Go to top/bottom"},
		{"?", "Toggle help overlay"},
		{"Esc", "Close modal/overlay/preview"},
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

// tailLines returns the last n lines of s.
func tailLines(s string, n int) string {
	lines := strings.Split(strings.TrimRight(s, "\n"), "\n")
	if len(lines) <= n {
		return strings.Join(lines, "\n")
	}
	return strings.Join(lines[len(lines)-n:], "\n")
}
