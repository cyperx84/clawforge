package main

import (
	"charm.land/lipgloss/v2"
)

// Forge theme colors.
var (
	colorPrimary   = lipgloss.Color("#FF8C00") // dark orange / amber
	colorSecondary = lipgloss.Color("#FFA500") // orange
	colorAccent    = lipgloss.Color("#FF6600") // red-orange
	colorMuted     = lipgloss.Color("#CC5500") // brown-orange
)

// Header style: bold + amber.
var headerStyle = lipgloss.NewStyle().
	Bold(true).
	Foreground(colorPrimary)

// Table header style: bold + secondary.
var tableHeaderStyle = lipgloss.NewStyle().
	Bold(true).
	Foreground(colorSecondary)

// Separator style: muted.
var separatorStyle = lipgloss.NewStyle().
	Foreground(colorMuted)

// Selected row: reverse + amber foreground.
var selectedRowStyle = lipgloss.NewStyle().
	Reverse(true).
	Foreground(colorPrimary)

// Status bar: dim + muted.
var statusBarStyle = lipgloss.NewStyle().
	Faint(true).
	Foreground(colorMuted)

// Borders: rounded, amber.
var borderStyle = lipgloss.NewStyle().
	Border(lipgloss.RoundedBorder()).
	BorderForeground(colorPrimary)

// Mode badge style.
var modeBadgeStyle = lipgloss.NewStyle().
	Bold(true).
	Padding(0, 1).
	Foreground(lipgloss.Color("#000000")).
	Background(colorSecondary)

// Status indicator styles.
var (
	statusRunningStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("#00FF00"))
	statusIdleStyle    = lipgloss.NewStyle().Foreground(lipgloss.Color("#FFFF00"))
	statusFailedStyle  = lipgloss.NewStyle().Foreground(lipgloss.Color("#FF0000"))
	statusDoneStyle    = lipgloss.NewStyle().Foreground(lipgloss.Color("#808080"))
)

// Help overlay style.
var helpOverlayStyle = lipgloss.NewStyle().
	Border(lipgloss.RoundedBorder()).
	BorderForeground(colorPrimary).
	Padding(1, 2).
	Foreground(colorSecondary)

// Animation frame style: centered, amber.
var animFrameStyle = lipgloss.NewStyle().
	Foreground(colorAccent).
	Bold(true)
