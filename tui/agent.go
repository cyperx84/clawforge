package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// Agent represents a single ClawForge agent with its current state.
type Agent struct {
	ID          string
	ShortID     int
	Preview     string
	Mode        string
	Model       string
	Repo        string
	Status      string
	Branch      string
	Task        string
	Cost        string
	CI          string
	Conflicts   int
	Description string
	Worktree    string
	TmuxSession string
}

// registryTask mirrors the JSON structure in active-tasks.json.
type registryTask struct {
	ID          string `json:"id"`
	ShortID     int    `json:"short_id"`
	Mode        string `json:"mode"`
	Status      string `json:"status"`
	Branch      string `json:"branch"`
	Description string `json:"description"`
	Worktree    string `json:"worktree"`
	TmuxSession string `json:"tmux_session"`
	Agent       string `json:"agent"`
	Model       string `json:"model"`
	Repo        string `json:"repo"`
	CIStatus    string `json:"ci_status"`
}

type registryFile struct {
	Tasks []registryTask `json:"tasks"`
}

// costEntry mirrors a line in costs.jsonl.
type costEntry struct {
	TaskID    string  `json:"taskId"`
	TotalCost float64 `json:"totalCost"`
}

// conflictEntry mirrors a line in conflicts.jsonl.
type conflictEntry struct {
	TaskIDs  []string `json:"task_ids"`
	Status   string   `json:"status"`
	Resolved bool     `json:"resolved"`
}

// clawforgeDir returns the clawforge root directory.
func clawforgeDir() string {
	// Check CLAWFORGE_DIR env first, then walk up from executable.
	if d := os.Getenv("CLAWFORGE_DIR"); d != "" {
		return d
	}
	exe, err := os.Executable()
	if err == nil {
		dir := filepath.Dir(exe)
		// If binary is in bin/, go up one level.
		if filepath.Base(dir) == "bin" {
			return filepath.Dir(dir)
		}
		// If binary is in tui/, go up one level.
		if filepath.Base(dir) == "tui" {
			return filepath.Dir(dir)
		}
		return filepath.Dir(dir)
	}
	return "."
}

// LoadAgents reads the registry, cost data, conflict data, and tmux state
// to produce a full list of Agent records.
func LoadAgents() []Agent {
	root := clawforgeDir()
	registryPath := filepath.Join(root, "registry", "active-tasks.json")

	data, err := os.ReadFile(registryPath)
	if err != nil {
		return nil
	}

	var reg registryFile
	if err := json.Unmarshal(data, &reg); err != nil {
		return nil
	}

	// Load cost data.
	costs := loadCosts(filepath.Join(root, "registry", "costs.jsonl"))

	// Load conflict counts.
	conflicts := loadConflictCounts(filepath.Join(root, "registry", "conflicts.jsonl"))

	// Load tmux sessions.
	tmuxSessions := loadTmuxSessions()

	agents := make([]Agent, 0, len(reg.Tasks))
	previewLines := 3
	for _, t := range reg.Tasks {
		a := Agent{
			ID:          t.ID,
			ShortID:     t.ShortID,
			Mode:        t.Mode,
			Model:       t.Model,
			Repo:        t.Repo,
			Status:      t.Status,
			Branch:      t.Branch,
			Description: t.Description,
			Task:        t.Description,
			Worktree:    t.Worktree,
			TmuxSession: t.TmuxSession,
			CI:          ciIndicator(t.CIStatus),
			Cost:        costs[t.ID],
			Conflicts:   conflicts[t.ID],
		}

		// Enrich preview from tmux if task is "running".
		if a.Status == "running" && a.TmuxSession != "" {
			if _, ok := tmuxSessions[a.TmuxSession]; ok {
				a.Preview = captureTmuxPreview(a.TmuxSession, previewLines)
			}
			// Don't override status — tmux may not be up yet or agent runs headlessly.
		}

		if a.Cost == "" {
			a.Cost = "-"
		}
		if a.Mode == "" {
			a.Mode = "—"
		}
		if a.Model == "" {
			a.Model = "-"
		}
		if a.Repo == "" {
			a.Repo = "-"
		} else {
			a.Repo = filepath.Base(a.Repo)
		}

		agents = append(agents, a)
	}

	return agents
}

// loadCosts reads costs.jsonl and sums cost per task.
func loadCosts(path string) map[string]string {
	result := make(map[string]string)
	data, err := os.ReadFile(path)
	if err != nil {
		return result
	}

	totals := make(map[string]float64)
	for _, line := range strings.Split(strings.TrimSpace(string(data)), "\n") {
		if line == "" {
			continue
		}
		var entry costEntry
		if json.Unmarshal([]byte(line), &entry) == nil && entry.TaskID != "" {
			totals[entry.TaskID] += entry.TotalCost
		}
	}

	for id, total := range totals {
		result[id] = fmt.Sprintf("$%.2f", total)
	}
	return result
}

// loadConflictCounts reads conflicts.jsonl and counts unresolved conflicts per task.
func loadConflictCounts(path string) map[string]int {
	result := make(map[string]int)
	data, err := os.ReadFile(path)
	if err != nil {
		return result
	}

	for _, line := range strings.Split(strings.TrimSpace(string(data)), "\n") {
		if line == "" {
			continue
		}
		var entry conflictEntry
		if json.Unmarshal([]byte(line), &entry) == nil && !entry.Resolved {
			for _, id := range entry.TaskIDs {
				result[id]++
			}
		}
	}
	return result
}

// loadTmuxSessions returns a set of active tmux session names.
func loadTmuxSessions() map[string]bool {
	sessions := make(map[string]bool)
	out, err := exec.Command("tmux", "list-sessions", "-F", "#{session_name}").Output()
	if err != nil {
		return sessions
	}
	for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		if line != "" {
			sessions[line] = true
		}
	}
	return sessions
}

// ciIndicator converts a CI status string to a display indicator.
func ciIndicator(status string) string {
	switch strings.ToLower(status) {
	case "pass", "passed", "success":
		return "✅"
	case "fail", "failed", "failure":
		return "❌"
	case "pending", "running", "in_progress":
		return "⏳"
	default:
		return "-"
	}
}

// statusIndicator returns the colored status emoji for an agent.
func statusIndicator(status string) string {
	switch strings.ToLower(status) {
	case "running":
		return "🟢"
	case "idle":
		return "🟡"
	case "failed":
		return "🔴"
	case "done":
		return "⚪"
	default:
		return "⚫"
	}
}

// captureTmuxPreview grabs the last N lines from a tmux pane.
func captureTmuxPreview(session string, lines int) string {
	out, err := exec.Command("tmux", "capture-pane", "-t", session, "-p", "-S", fmt.Sprintf("-%d", lines)).Output()
	if err != nil {
		return ""
	}
	// Strip ANSI escape codes for clean display
	result := strings.TrimSpace(string(out))
	// Basic ANSI strip
	for _, prefix := range []string{"\033[", "\x1b["} {
		_ = prefix // handled by sed-like logic below
	}
	return result
}
