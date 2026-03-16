package fleet

import (
	"encoding/json"
	"fmt"
	"strings"
)

// DiffResult represents the comparison between two agents
type DiffResult struct {
	Agent1     string       `json:"agent1"`
	Agent2     string       `json:"agent2"`
	ConfigDiff []DiffEntry  `json:"config_diff"`
	FileDiffs  []FileDiff   `json:"file_diffs,omitempty"`
}

// DiffEntry represents a single config difference
type DiffEntry struct {
	Field  string `json:"field"`
	Value1 string `json:"value1"`
	Value2 string `json:"value2"`
}

// FileDiff represents a diff of a workspace file
type FileDiff struct {
	Filename   string `json:"filename"`
	Lines1     int    `json:"lines1"`
	Lines2     int    `json:"lines2"`
	Sections1  []string `json:"sections1,omitempty"`
	Sections2  []string `json:"sections2,omitempty"`
	Identical  bool   `json:"identical"`
	FullDiff   string `json:"full_diff,omitempty"`
}

// CompareAgents compares two agents' configs and workspace files
func CompareAgents(id1, id2 string, includeFiles bool) (*DiffResult, error) {
	agent1, err := GetAgent(id1)
	if err != nil {
		return nil, fmt.Errorf("agent %s: %w", id1, err)
	}
	agent2, err := GetAgent(id2)
	if err != nil {
		return nil, fmt.Errorf("agent %s: %w", id2, err)
	}

	result := &DiffResult{
		Agent1: id1,
		Agent2: id2,
	}

	// Compare config fields
	if agent1.Name != agent2.Name {
		result.ConfigDiff = append(result.ConfigDiff, DiffEntry{"name", agent1.Name, agent2.Name})
	}
	if agent1.Role != agent2.Role {
		result.ConfigDiff = append(result.ConfigDiff, DiffEntry{"role", agent1.Role, agent2.Role})
	}
	if agent1.Emoji != agent2.Emoji {
		result.ConfigDiff = append(result.ConfigDiff, DiffEntry{"emoji", agent1.Emoji, agent2.Emoji})
	}
	model1 := ResolveModelDisplay(agent1.Model)
	model2 := ResolveModelDisplay(agent2.Model)
	if model1 != model2 {
		result.ConfigDiff = append(result.ConfigDiff, DiffEntry{"model", model1, model2})
	}
	if agent1.Status != agent2.Status {
		result.ConfigDiff = append(result.ConfigDiff, DiffEntry{"status", agent1.Status, agent2.Status})
	}
	b1 := fmt.Sprintf("%d", len(agent1.Bindings))
	b2 := fmt.Sprintf("%d", len(agent2.Bindings))
	if b1 != b2 {
		result.ConfigDiff = append(result.ConfigDiff, DiffEntry{"bindings", b1, b2})
	}

	// Compare workspace files
	compareFiles := []string{"SOUL.md", "AGENTS.md", "TOOLS.md"}
	if includeFiles {
		compareFiles = AgentFiles
	}

	for _, filename := range compareFiles {
		content1, err1 := ReadWorkspaceFile(id1, filename)
		content2, err2 := ReadWorkspaceFile(id2, filename)

		fd := FileDiff{
			Filename: filename,
		}

		if err1 != nil {
			content1 = ""
		}
		if err2 != nil {
			content2 = ""
		}

		fd.Lines1 = countLines(content1)
		fd.Lines2 = countLines(content2)
		fd.Sections1 = extractSections(content1)
		fd.Sections2 = extractSections(content2)
		fd.Identical = content1 == content2

		if includeFiles && !fd.Identical {
			fd.FullDiff = generateSimpleDiff(content1, content2)
		}

		result.FileDiffs = append(result.FileDiffs, fd)
	}

	return result, nil
}

// CompareAgentsFromData compares two agents directly (for testing)
func CompareAgentsFromData(a1, a2 *Agent, files1, files2 map[string]string, includeFiles bool) *DiffResult {
	result := &DiffResult{
		Agent1: a1.ID,
		Agent2: a2.ID,
	}

	if a1.Name != a2.Name {
		result.ConfigDiff = append(result.ConfigDiff, DiffEntry{"name", a1.Name, a2.Name})
	}
	if a1.Role != a2.Role {
		result.ConfigDiff = append(result.ConfigDiff, DiffEntry{"role", a1.Role, a2.Role})
	}
	model1 := ResolveModelDisplay(a1.Model)
	model2 := ResolveModelDisplay(a2.Model)
	if model1 != model2 {
		result.ConfigDiff = append(result.ConfigDiff, DiffEntry{"model", model1, model2})
	}

	compareFiles := []string{"SOUL.md", "AGENTS.md", "TOOLS.md"}
	if includeFiles {
		compareFiles = AgentFiles
	}

	for _, filename := range compareFiles {
		c1 := files1[filename]
		c2 := files2[filename]
		fd := FileDiff{
			Filename:  filename,
			Lines1:    countLines(c1),
			Lines2:    countLines(c2),
			Sections1: extractSections(c1),
			Sections2: extractSections(c2),
			Identical: c1 == c2,
		}
		if includeFiles && !fd.Identical {
			fd.FullDiff = generateSimpleDiff(c1, c2)
		}
		result.FileDiffs = append(result.FileDiffs, fd)
	}

	return result
}

func countLines(s string) int {
	if s == "" {
		return 0
	}
	return strings.Count(s, "\n") + 1
}

func extractSections(content string) []string {
	var sections []string
	for _, line := range strings.Split(content, "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "## ") {
			sections = append(sections, trimmed[3:])
		} else if strings.HasPrefix(trimmed, "# ") {
			sections = append(sections, trimmed[2:])
		}
	}
	return sections
}

func generateSimpleDiff(a, b string) string {
	linesA := strings.Split(a, "\n")
	linesB := strings.Split(b, "\n")

	var diff string
	maxLen := len(linesA)
	if len(linesB) > maxLen {
		maxLen = len(linesB)
	}

	for i := 0; i < maxLen; i++ {
		lineA := ""
		lineB := ""
		if i < len(linesA) {
			lineA = linesA[i]
		}
		if i < len(linesB) {
			lineB = linesB[i]
		}

		if lineA != lineB {
			if lineA != "" {
				diff += fmt.Sprintf("- %s\n", lineA)
			}
			if lineB != "" {
				diff += fmt.Sprintf("+ %s\n", lineB)
			}
		}
	}
	return diff
}

// FormatDiff returns human-readable diff output
func FormatDiff(result *DiffResult) string {
	var s string
	s += fmt.Sprintf("Comparing: %s vs %s\n\n", result.Agent1, result.Agent2)

	if len(result.ConfigDiff) == 0 {
		s += "Config: identical\n"
	} else {
		s += "Config differences:\n"
		for _, d := range result.ConfigDiff {
			s += fmt.Sprintf("  %-10s  %s → %s\n", d.Field, d.Value1, d.Value2)
		}
	}

	s += "\n"

	if len(result.FileDiffs) > 0 {
		s += "Workspace files:\n"
		for _, fd := range result.FileDiffs {
			icon := "="
			if !fd.Identical {
				icon := "≠"
				_ = icon
			}
			if fd.Identical {
				icon = "="
			} else {
				icon = "≠"
			}
			s += fmt.Sprintf("  %s %-15s  %d lines vs %d lines\n",
				icon, fd.Filename, fd.Lines1, fd.Lines2)
			if fd.FullDiff != "" {
				for _, line := range strings.Split(fd.FullDiff, "\n") {
					if line != "" {
						s += fmt.Sprintf("    %s\n", line)
					}
				}
			}
		}
	}

	return s
}

// FormatDiffJSON returns JSON diff output
func FormatDiffJSON(result *DiffResult) (string, error) {
	data, err := json.MarshalIndent(result, "", "  ")
	if err != nil {
		return "", err
	}
	return string(data), nil
}
