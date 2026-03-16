package fleet

import (
	"testing"

	"github.com/cyperx84/clawforge/internal/config"
)

func TestCompareAgentsFromData(t *testing.T) {
	a1 := &Agent{
		Agent: config.Agent{ID: "agent1", Name: "Alpha", Role: "coder", Model: "claude-opus-4-6"},
	}
	a2 := &Agent{
		Agent: config.Agent{ID: "agent2", Name: "Beta", Role: "researcher", Model: "claude-sonnet-4-6"},
	}

	files1 := map[string]string{
		"SOUL.md":   "# Alpha Soul\n## Purpose\nCoding agent\n",
		"AGENTS.md": "# Known Agents\n",
		"TOOLS.md":  "# Tools\n",
	}
	files2 := map[string]string{
		"SOUL.md":   "# Beta Soul\n## Purpose\nResearch agent\n## Methods\nLiterature review\n",
		"AGENTS.md": "# Known Agents\n",
		"TOOLS.md":  "# Tools\n## Custom\nWeb search\n",
	}

	result := CompareAgentsFromData(a1, a2, files1, files2, false)

	// Should detect config differences
	if len(result.ConfigDiff) < 2 {
		t.Errorf("Expected at least 2 config diffs, got %d", len(result.ConfigDiff))
	}

	// Check name diff exists
	foundName := false
	for _, d := range result.ConfigDiff {
		if d.Field == "name" && d.Value1 == "Alpha" && d.Value2 == "Beta" {
			foundName = true
		}
	}
	if !foundName {
		t.Error("Expected to find name diff")
	}

	// File diffs
	if len(result.FileDiffs) != 3 {
		t.Errorf("Expected 3 file diffs, got %d", len(result.FileDiffs))
	}

	// AGENTS.md should be identical
	for _, fd := range result.FileDiffs {
		if fd.Filename == "AGENTS.md" && !fd.Identical {
			t.Error("Expected AGENTS.md to be identical")
		}
		if fd.Filename == "SOUL.md" && fd.Identical {
			t.Error("Expected SOUL.md to differ")
		}
	}
}

func TestCompareAgentsIdentical(t *testing.T) {
	a := &Agent{
		Agent: config.Agent{ID: "same", Name: "Same", Role: "coder", Model: "claude-opus-4-6"},
	}

	files := map[string]string{
		"SOUL.md":   "# Same\n",
		"AGENTS.md": "# Agents\n",
		"TOOLS.md":  "# Tools\n",
	}

	result := CompareAgentsFromData(a, a, files, files, false)

	if len(result.ConfigDiff) != 0 {
		t.Errorf("Expected 0 config diffs for identical agents, got %d", len(result.ConfigDiff))
	}

	for _, fd := range result.FileDiffs {
		if !fd.Identical {
			t.Errorf("Expected %s to be identical", fd.Filename)
		}
	}
}

func TestExtractSections(t *testing.T) {
	content := "# Title\n## Section One\nContent\n## Section Two\nMore content\n"
	sections := extractSections(content)
	if len(sections) != 3 {
		t.Errorf("Expected 3 sections, got %d: %v", len(sections), sections)
	}
}

func TestCountLines(t *testing.T) {
	if countLines("") != 0 {
		t.Error("Expected 0 for empty string")
	}
	if countLines("a\nb\nc") != 3 {
		t.Errorf("Expected 3 lines, got %d", countLines("a\nb\nc"))
	}
}

func TestFormatDiff(t *testing.T) {
	result := &DiffResult{
		Agent1: "a1",
		Agent2: "a2",
		ConfigDiff: []DiffEntry{
			{Field: "name", Value1: "Alpha", Value2: "Beta"},
		},
		FileDiffs: []FileDiff{
			{Filename: "SOUL.md", Lines1: 10, Lines2: 15, Identical: false},
		},
	}
	output := FormatDiff(result)
	if output == "" {
		t.Error("Expected non-empty output")
	}
}
