package observability

import (
	"testing"
)

func TestParseHeartbeatField(t *testing.T) {
	content := `# Heartbeat

**Last Active**: 2026-03-15T10:30:00Z
**Uptime**: 48h
**Status**: active
`

	val := parseHeartbeatField(content, "Last Active")
	if val != "2026-03-15T10:30:00Z" {
		t.Errorf("Expected '2026-03-15T10:30:00Z', got '%s'", val)
	}

	val = parseHeartbeatField(content, "Status")
	if val != "active" {
		t.Errorf("Expected 'active', got '%s'", val)
	}

	val = parseHeartbeatField(content, "Nonexistent")
	if val != "" {
		t.Errorf("Expected empty string, got '%s'", val)
	}
}

func TestParseHeartbeatFieldAutoUpdated(t *testing.T) {
	content := `# Heartbeat

**Last Active**: *auto-updated*
**Status**: active
`
	val := parseHeartbeatField(content, "Last Active")
	if val != "auto-updated" {
		t.Errorf("Expected 'auto-updated', got '%s'", val)
	}
}

func TestFormatHealth(t *testing.T) {
	healths := []AgentHealth{
		{ID: "test-1", Name: "Test Agent", Status: "active", LastActive: "2026-03-15", SessionCount: 3, Healthy: true},
		{ID: "test-2", Name: "Broken", Status: "created", LastActive: "unknown", SessionCount: 0, Healthy: false, HasErrors: true},
	}

	output := FormatHealth(healths)
	if output == "" {
		t.Error("Expected non-empty output")
	}

	// Test empty
	output = FormatHealth(nil)
	if output != "No agents found.\n" {
		t.Errorf("Expected 'No agents found.' for empty, got: %s", output)
	}
}

func TestFormatHealthJSON(t *testing.T) {
	healths := []AgentHealth{
		{ID: "test-1", Name: "Test", Healthy: true},
	}
	jsonStr, err := FormatHealthJSON(healths)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if jsonStr == "" {
		t.Error("Expected non-empty JSON")
	}
}
