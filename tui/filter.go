package main

import (
	"strings"

	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
)

// handleFilterKey processes key input while in filter mode.
func handleFilterKey(m Model, key string) (Model, tea.Cmd) {
	switch key {
	case "esc":
		m.filterMode = false
		m.filter = ""
		m.selected = 0
		return m, nil
	case "enter":
		m.filterMode = false
		return m, nil
	case "backspace":
		if len(m.filter) > 0 {
			m.filter = m.filter[:len(m.filter)-1]
			// Reset selection when filter changes.
			m.selected = 0
		}
		return m, nil
	default:
		if len(key) == 1 {
			m.filter += key
			m.selected = 0
		} else if key == "space" {
			m.filter += " "
			m.selected = 0
		}
		return m, nil
	}
}

// FilterAgents returns agents matching the query via case-insensitive substring
// match across all display fields.
func FilterAgents(agents []Agent, query string) []Agent {
	if query == "" {
		return agents
	}
	q := strings.ToLower(query)
	var results []Agent
	for _, a := range agents {
		haystack := strings.ToLower(
			a.ID + " " + a.Mode + " " + a.Status + " " + a.Branch + " " + a.Description,
		)
		if strings.Contains(haystack, q) {
			results = append(results, a)
		}
	}
	return results
}

// RenderFilterBar renders the filter input bar shown at the top of the screen.
func RenderFilterBar(m Model) string {
	prompt := "/ " + m.filter
	cursor := "█"

	return lipgloss.NewStyle().
		Foreground(lipgloss.Color("#FFA500")).
		Bold(true).
		Render(prompt + cursor)
}
