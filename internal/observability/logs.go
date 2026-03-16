package observability

import (
	"bufio"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/cyperx84/clawforge/internal/fleet"
)

// LogEntry represents a single log entry
type LogEntry struct {
	Timestamp time.Time
	Level     string
	Message   string
}

// GetAgentLogs reads recent log files for an agent
func GetAgentLogs(id string, tail int) ([]LogEntry, error) {
	workspace, err := fleet.GetWorkspace(id)
	if err != nil {
		return nil, err
	}

	memoryDir := filepath.Join(workspace, "memory")
	entries, err := os.ReadDir(memoryDir)
	if err != nil {
		return nil, nil // Return empty if directory doesn't exist
	}

	// Get the most recent log files
	var logFiles []string
	for _, entry := range entries {
		if !entry.IsDir() && strings.HasSuffix(entry.Name(), ".md") {
			logFiles = append(logFiles, filepath.Join(memoryDir, entry.Name()))
		}
	}

	// Sort in reverse chronological order
	sort.Slice(logFiles, func(i, j int) bool {
		return logFiles[i] > logFiles[j]
	})

	// Take the most recent tail files
	if len(logFiles) > tail {
		logFiles = logFiles[:tail]
	}

	var logs []LogEntry
	for _, file := range logFiles {
		data, err := os.ReadFile(file)
		if err != nil {
			continue
		}

		// Parse file content line by line
		scanner := bufio.NewScanner(strings.NewReader(string(data)))
		for scanner.Scan() {
			line := scanner.Text()
			if strings.TrimSpace(line) == "" {
				continue
			}
			logs = append(logs, LogEntry{
				Timestamp: time.Now(),
				Level:     "info",
				Message:   line,
			})
		}
	}

	return logs, nil
}

// StreamLogs provides a channel for real-time log streaming
func StreamLogs(id string, follow bool) (<-chan LogEntry, error) {
	logChan := make(chan LogEntry)
	go func() {
		defer close(logChan)
		// Placeholder for streaming logs
		// In a real implementation, this would watch the memory directory for new files
	}()
	return logChan, nil
}

// SearchLogs searches logs for a pattern
func SearchLogs(id string, pattern string) ([]LogEntry, error) {
	logs, err := GetAgentLogs(id, 100)
	if err != nil {
		return nil, err
	}

	var matches []LogEntry
	for _, log := range logs {
		if strings.Contains(strings.ToLower(log.Message), strings.ToLower(pattern)) {
			matches = append(matches, log)
		}
	}
	return matches, nil
}
