package main

import (
	"fmt"
	"strings"

	"charm.land/lipgloss/v2"
)

// Column widths for the agent table.
const (
	colID       = 5
	colMode     = 8
	colStatus   = 10
	colRepo     = 12
	colModel    = 12
	colBranch   = 18
	colTask     = 24
	colCost     = 8
	colCI       = 4
	colConflict = 5
)

// renderDashboard renders the main dashboard view.
func renderDashboard(m Model) string {
	var b strings.Builder

	// Header.
	title := headerStyle.Render("⚒️  ClawForge Dashboard")
	b.WriteString(title)
	b.WriteString("\n\n")

	// Filter bar (if active).
	if m.filterMode {
		b.WriteString(RenderFilterBar(m))
		b.WriteString("\n\n")
	}

	agents := m.filteredAgents()

	// Table header row.
	hdr := tableHeaderStyle.Render(
		padRight("ID", colID) +
			padRight("Mode", colMode) +
			padRight("Status", colStatus) +
			padRight("Repo", colRepo) +
			padRight("Model", colModel) +
			padRight("Branch", colBranch) +
			padRight("Task", colTask) +
			padRight("Cost", colCost) +
			padRight("CI", colCI) +
			padRight("Cnfl", colConflict),
	)
	b.WriteString(hdr)
	b.WriteString("\n")

	// Separator.
	totalWidth := colID + colMode + colStatus + colRepo + colModel + colBranch + colTask + colCost + colCI + colConflict
	b.WriteString(separatorStyle.Render(strings.Repeat("─", totalWidth)))
	b.WriteString("\n")

	if len(agents) == 0 {
		empty := lipgloss.NewStyle().Faint(true).Render("  No agents found.")
		b.WriteString(empty)
		b.WriteString("\n")
	} else {
		// Determine how many rows to show based on terminal height.
		maxRows := len(agents)
		if m.height > 0 {
			// Reserve lines for header(2) + table header(1) + separator(1) + footer(2) + steer(1) + padding(1).
			available := m.height - 8
			if m.filterMode {
				available -= 2
			}
			if available < 1 {
				available = 1
			}
			if maxRows > available {
				maxRows = available
			}
		}

		// Scroll offset: keep selected row visible.
		offset := 0
		if m.selected >= maxRows {
			offset = m.selected - maxRows + 1
		}

		for i := offset; i < offset+maxRows && i < len(agents); i++ {
			a := agents[i]
			row := renderAgentRow(a)
			if i == m.selected {
				row = selectedRowStyle.Render(row)
			}
			b.WriteString(row)
			b.WriteString("\n")
		}
	}

	// Steer input (if active).
	if m.steerMode {
		b.WriteString("\n")
		b.WriteString(RenderSteerInput(m))
		b.WriteString("\n")
	}

	// Help overlay.
	if m.showHelp {
		b.WriteString("\n")
		b.WriteString(renderHelpOverlay(m.width))
		b.WriteString("\n")
	}

	// Footer status bar.
	b.WriteString("\n")
	b.WriteString(renderStatusBar(m))

	return b.String()
}

// renderAgentRow formats a single agent as a table row.
func renderAgentRow(a Agent) string {
	id := a.ID
	if a.ShortID > 0 {
		id = fmt.Sprintf("#%d", a.ShortID)
	}

	status := statusIndicator(a.Status) + " " + a.Status

	conflictStr := "-"
	if a.Conflicts > 0 {
		conflictStr = fmt.Sprintf("%d", a.Conflicts)
	}

	return padRight(truncate(id, colID), colID) +
		padRight(truncate(a.Mode, colMode), colMode) +
		padRight(truncate(status, colStatus), colStatus) +
		padRight(truncate(a.Repo, colRepo), colRepo) +
		padRight(truncate(a.Model, colModel), colModel) +
		padRight(truncate(a.Branch, colBranch), colBranch) +
		padRight(truncate(a.Task, colTask), colTask) +
		padRight(truncate(a.Cost, colCost), colCost) +
		padRight(truncate(a.CI, colCI), colCI) +
		padRight(truncate(conflictStr, colConflict), colConflict)
}

// renderStatusBar renders the footer status bar.
func renderStatusBar(m Model) string {
	agents := m.filteredAgents()
	total := len(agents)
	running := 0
	var totalCost float64

	for _, a := range agents {
		if a.Status == "running" {
			running++
		}
		// Parse cost for summary.
		if a.Cost != "-" && a.Cost != "" {
			var c float64
			fmt.Sscanf(a.Cost, "$%f", &c)
			totalCost += c
		}
	}

	costStr := "-"
	if totalCost > 0 {
		costStr = fmt.Sprintf("$%.2f", totalCost)
	}

	bar := fmt.Sprintf(" %d agents | %d running | %s total | j/k navigate | ? help | q quit",
		total, running, costStr)

	return statusBarStyle.Render(bar)
}

// truncate shortens a string to maxLen, adding "…" if needed.
func truncate(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	if maxLen <= 1 {
		return "…"
	}
	return s[:maxLen-1] + "…"
}

// padRight pads a string with spaces to the given width.
func padRight(s string, width int) string {
	if len(s) >= width {
		return s
	}
	return s + strings.Repeat(" ", width-len(s))
}
