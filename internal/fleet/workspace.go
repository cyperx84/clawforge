package fleet

import (
	"os"
	"path/filepath"
	"strings"
)

// WorkspaceFile represents a file in an agent's workspace
type WorkspaceFile struct {
	Name   string // e.g., "SOUL.md"
	Path   string
	Status string // "exists", "empty", "missing", "template", "unfilled"
}

// AgentFiles are the standard files every agent should have
var AgentFiles = []string{"SOUL.md", "AGENTS.md", "TOOLS.md", "USER.md", "IDENTITY.md", "MEMORY.md", "HEARTBEAT.md"}

// GetWorkspaceFiles returns the status of all standard workspace files
func GetWorkspaceFiles(id string) ([]WorkspaceFile, error) {
	workspace, err := GetWorkspace(id)
	if err != nil {
		return nil, err
	}

	var files []WorkspaceFile
	for _, name := range AgentFiles {
		path := filepath.Join(workspace, name)
		status := checkFileStatus(path)
		files = append(files, WorkspaceFile{
			Name:   name,
			Path:   path,
			Status: status,
		})
	}
	return files, nil
}

// CreateWorkspace initializes a new workspace directory
func CreateWorkspace(id string) (string, error) {
	workspace, err := GetWorkspace(id)
	if err != nil {
		return "", err
	}

	if err := os.MkdirAll(workspace, 0755); err != nil {
		return "", err
	}

	// Create subdirectories
	for _, dir := range []string{"memory", "references"} {
		if err := os.MkdirAll(filepath.Join(workspace, dir), 0755); err != nil {
			return "", err
		}
	}

	// Create empty workspace files
	for _, name := range AgentFiles {
		path := filepath.Join(workspace, name)
		if err := os.WriteFile(path, []byte{}, 0644); err != nil {
			return "", err
		}
	}

	return workspace, nil
}

// WriteWorkspaceFile writes content to a workspace file
func WriteWorkspaceFile(id, filename string, content string) error {
	workspace, err := GetWorkspace(id)
	if err != nil {
		return err
	}
	path := filepath.Join(workspace, filename)
	return os.WriteFile(path, []byte(content), 0644)
}

// ReadWorkspaceFile reads the content of a workspace file
func ReadWorkspaceFile(id, filename string) (string, error) {
	workspace, err := GetWorkspace(id)
	if err != nil {
		return "", err
	}
	path := filepath.Join(workspace, filename)
	data, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	return string(data), nil
}

// checkFileStatus checks the status of a file
func checkFileStatus(path string) string {
	info, err := os.Stat(path)
	if err != nil {
		return "missing"
	}

	if info.Size() == 0 {
		return "empty"
	}

	data, err := os.ReadFile(path)
	if err != nil {
		return "missing"
	}

	content := string(data)

	// Check for template placeholders
	if strings.Contains(content, "{{") && strings.Contains(content, "}}") {
		return "template"
	}

	// Check for unfilled markers
	if strings.HasPrefix(strings.TrimSpace(content), "*") {
		return "unfilled"
	}

	return "exists"
}

// CountMemoryFiles counts daily log files in the memory directory
func CountMemoryFiles(id string) (int, error) {
	workspace, err := GetWorkspace(id)
	if err != nil {
		return 0, err
	}

	memoryDir := filepath.Join(workspace, "memory")
	entries, err := os.ReadDir(memoryDir)
	if err != nil {
		return 0, nil // Return 0 if directory doesn't exist
	}

	count := 0
	for _, entry := range entries {
		if !entry.IsDir() && strings.HasSuffix(entry.Name(), ".md") {
			count++
		}
	}
	return count, nil
}

// CountReferenceFiles counts reference files
func CountReferenceFiles(id string) (int, error) {
	workspace, err := GetWorkspace(id)
	if err != nil {
		return 0, err
	}

	refsDir := filepath.Join(workspace, "references")
	entries, err := os.ReadDir(refsDir)
	if err != nil {
		return 0, nil // Return 0 if directory doesn't exist
	}

	count := 0
	for _, entry := range entries {
		if !entry.IsDir() {
			count++
		}
	}
	return count, nil
}

// DeleteWorkspace removes the agent's workspace directory
func DeleteWorkspace(id string) error {
	workspace, err := GetWorkspace(id)
	if err != nil {
		return err
	}

	if _, err := os.Stat(workspace); err == nil {
		return os.RemoveAll(workspace)
	}
	return nil
}

// StatusIcon returns an icon for the agent status
func StatusIcon(status string) string {
	switch status {
	case "active":
		return "●"
	case "created":
		return "○"
	case "config-only":
		return "◌"
	default:
		return "?"
	}
}

// FileStatusIcon returns an icon for file status
func FileStatusIcon(status string) string {
	switch status {
	case "exists":
		return "✓"
	case "empty":
		return "○"
	case "missing":
		return "✗"
	case "template", "unfilled":
		return "⚠"
	default:
		return "?"
	}
}
