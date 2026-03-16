package fleet

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"github.com/cyperx84/clawforge/internal/config"
)

// SyncResult represents the result of a sync check
type SyncResult struct {
	DiskOnly   []string `json:"disk_only"`   // On disk but not in config
	ConfigOnly []string `json:"config_only"` // In config but not on disk
	InSync     []string `json:"in_sync"`     // Present in both
}

// DetectDrift compares disk agents with config agents
func DetectDrift() (*SyncResult, error) {
	cfg, err := config.ReadOpenClawConfig()
	if err != nil {
		return nil, fmt.Errorf("failed to read config: %w", err)
	}

	agentsDir, err := config.AgentsDir()
	if err != nil {
		return nil, err
	}

	// Collect config agent IDs
	configIDs := make(map[string]bool)
	for _, a := range cfg.Agents.List {
		configIDs[a.ID] = true
	}

	// Collect disk agent IDs (dirs with SOUL.md)
	diskIDs := make(map[string]bool)
	entries, err := os.ReadDir(agentsDir)
	if err != nil && !os.IsNotExist(err) {
		return nil, fmt.Errorf("failed to read agents dir: %w", err)
	}
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		soulPath := filepath.Join(agentsDir, entry.Name(), "SOUL.md")
		if _, err := os.Stat(soulPath); err == nil {
			diskIDs[entry.Name()] = true
		}
	}

	result := &SyncResult{}

	// Find disk-only agents
	for id := range diskIDs {
		if configIDs[id] {
			result.InSync = append(result.InSync, id)
		} else {
			result.DiskOnly = append(result.DiskOnly, id)
		}
	}

	// Find config-only agents
	for id := range configIDs {
		if !diskIDs[id] {
			result.ConfigOnly = append(result.ConfigOnly, id)
		}
	}

	return result, nil
}

// DetectDriftWithPaths is like DetectDrift but uses custom paths for testing
func DetectDriftWithPaths(agentsDir string, cfg *config.OpenClawConfig) (*SyncResult, error) {
	configIDs := make(map[string]bool)
	for _, a := range cfg.Agents.List {
		configIDs[a.ID] = true
	}

	diskIDs := make(map[string]bool)
	entries, err := os.ReadDir(agentsDir)
	if err != nil && !os.IsNotExist(err) {
		return nil, fmt.Errorf("failed to read agents dir: %w", err)
	}
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		soulPath := filepath.Join(agentsDir, entry.Name(), "SOUL.md")
		if _, err := os.Stat(soulPath); err == nil {
			diskIDs[entry.Name()] = true
		}
	}

	result := &SyncResult{}
	for id := range diskIDs {
		if configIDs[id] {
			result.InSync = append(result.InSync, id)
		} else {
			result.DiskOnly = append(result.DiskOnly, id)
		}
	}
	for id := range configIDs {
		if !diskIDs[id] {
			result.ConfigOnly = append(result.ConfigOnly, id)
		}
	}

	return result, nil
}

// FixDrift adds disk-only agents to the config via the openclaw CLI
func FixDrift(result *SyncResult) (int, error) {
	if len(result.DiskOnly) == 0 {
		return 0, nil
	}

	agentsDir, err := config.AgentsDir()
	if err != nil {
		return 0, err
	}

	added := 0
	for _, id := range result.DiskOnly {
		wsPath := filepath.Join(agentsDir, id)
		name := id
		if soulContent, err := os.ReadFile(filepath.Join(wsPath, "SOUL.md")); err == nil {
			if extracted := extractNameFromSoul(string(soulContent)); extracted != "" {
				name = extracted
			}
		}

		if err := OpenClawAgentAdd(id, name, "", wsPath); err != nil {
			return added, fmt.Errorf("failed to add agent %s: %w", id, err)
		}
		added++
	}

	return added, nil
}

// FormatSyncResult returns a human-readable string of the sync result
func FormatSyncResult(result *SyncResult) string {
	var s string

	if len(result.DiskOnly) == 0 && len(result.ConfigOnly) == 0 {
		return "No drift detected. All agents are in sync.\n"
	}

	if len(result.DiskOnly) > 0 {
		s += "Agents on disk but NOT in config:\n"
		for _, id := range result.DiskOnly {
			s += fmt.Sprintf("  + %s\n", id)
		}
	}

	if len(result.ConfigOnly) > 0 {
		s += "Agents in config but NOT on disk:\n"
		for _, id := range result.ConfigOnly {
			s += fmt.Sprintf("  - %s\n", id)
		}
	}

	if len(result.InSync) > 0 {
		s += fmt.Sprintf("\nIn sync: %d agent(s)\n", len(result.InSync))
	}

	return s
}

// FormatSyncJSON returns JSON output of the sync result
func FormatSyncJSON(result *SyncResult) (string, error) {
	data, err := json.MarshalIndent(result, "", "  ")
	if err != nil {
		return "", err
	}
	return string(data), nil
}
