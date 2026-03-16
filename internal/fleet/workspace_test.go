package fleet

import (
	"os"
	"path/filepath"
	"testing"
)

func TestCheckFileStatus(t *testing.T) {
	tmpDir := t.TempDir()

	// Test missing file
	missingPath := filepath.Join(tmpDir, "nonexistent.md")
	if status := checkFileStatus(missingPath); status != "missing" {
		t.Errorf("missing file: got %q, want %q", status, "missing")
	}

	// Test empty file
	emptyPath := filepath.Join(tmpDir, "empty.md")
	os.WriteFile(emptyPath, []byte{}, 0644)
	if status := checkFileStatus(emptyPath); status != "empty" {
		t.Errorf("empty file: got %q, want %q", status, "empty")
	}

	// Test file with content
	normalPath := filepath.Join(tmpDir, "normal.md")
	os.WriteFile(normalPath, []byte("# Hello\nSome content here."), 0644)
	if status := checkFileStatus(normalPath); status != "exists" {
		t.Errorf("normal file: got %q, want %q", status, "exists")
	}

	// Test file with template placeholders
	templatePath := filepath.Join(tmpDir, "template.md")
	os.WriteFile(templatePath, []byte("Name: {{NAME}}\nRole: {{ROLE}}"), 0644)
	if status := checkFileStatus(templatePath); status != "template" {
		t.Errorf("template file: got %q, want %q", status, "template")
	}

	// Test file with unfilled marker
	unfilledPath := filepath.Join(tmpDir, "unfilled.md")
	os.WriteFile(unfilledPath, []byte("*To be filled by user*"), 0644)
	if status := checkFileStatus(unfilledPath); status != "unfilled" {
		t.Errorf("unfilled file: got %q, want %q", status, "unfilled")
	}
}

func TestStatusIcon(t *testing.T) {
	tests := []struct {
		status   string
		expected string
	}{
		{"active", "●"},
		{"created", "○"},
		{"config-only", "◌"},
		{"unknown", "?"},
		{"garbage", "?"},
	}

	for _, tt := range tests {
		result := StatusIcon(tt.status)
		if result != tt.expected {
			t.Errorf("StatusIcon(%q) = %q, want %q", tt.status, result, tt.expected)
		}
	}
}

func TestFileStatusIcon(t *testing.T) {
	tests := []struct {
		status   string
		expected string
	}{
		{"exists", "✓"},
		{"empty", "○"},
		{"missing", "✗"},
		{"template", "⚠"},
		{"unfilled", "⚠"},
		{"unknown", "?"},
	}

	for _, tt := range tests {
		result := FileStatusIcon(tt.status)
		if result != tt.expected {
			t.Errorf("FileStatusIcon(%q) = %q, want %q", tt.status, result, tt.expected)
		}
	}
}

func TestAgentFilesContainsExpected(t *testing.T) {
	expected := map[string]bool{
		"SOUL.md":      true,
		"AGENTS.md":    true,
		"TOOLS.md":     true,
		"USER.md":      true,
		"IDENTITY.md":  true,
		"MEMORY.md":    true,
		"HEARTBEAT.md": true,
	}

	if len(AgentFiles) != len(expected) {
		t.Fatalf("AgentFiles has %d entries, want %d", len(AgentFiles), len(expected))
	}

	for _, f := range AgentFiles {
		if !expected[f] {
			t.Errorf("unexpected file in AgentFiles: %q", f)
		}
	}
}
