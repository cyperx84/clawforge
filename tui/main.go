package main

import (
	"fmt"
	"os"

	tea "charm.land/bubbletea/v2"
	"github.com/charmbracelet/x/term"
)

const usageText = `Usage: clawforge dashboard [options]

Live terminal UI for monitoring all ClawForge agents.

Options:
  --no-anim    Skip startup animation
  --help       Show this help

Keybindings:
  j/k          Navigate agent list
  Enter        Attach to selected agent's tmux session
  s            Steer selected agent (prompts for message)
  x            Stop selected agent
  /            Filter agents
  1/2/3        Views: all / running / finished
  Tab          Cycle views
  n            Nudge selected running agent
  r            Force refresh
  ?            Show help overlay
  q            Quit dashboard`

func main() {
	noAnim := false
	for _, arg := range os.Args[1:] {
		switch arg {
		case "--help", "-h":
			fmt.Println(usageText)
			os.Exit(0)
		case "--no-anim":
			noAnim = true
		default:
			fmt.Fprintf(os.Stderr, "Unknown option: %s\n", arg)
			fmt.Fprintln(os.Stderr, usageText)
			os.Exit(1)
		}
	}

	// If stdin or stdout is not a terminal, show help and exit (for CI/scripting).
	if !term.IsTerminal(os.Stdin.Fd()) || !term.IsTerminal(os.Stdout.Fd()) {
		fmt.Println(usageText)
		os.Exit(0)
	}

	m := NewModel(noAnim)
	p := tea.NewProgram(m)
	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}
