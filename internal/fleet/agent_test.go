package fleet

import "testing"

func TestExtractNameFromSoul(t *testing.T) {
	tests := []struct {
		name     string
		content  string
		expected string
	}{
		{
			name:     "SOUL.md header format",
			content:  "# SOUL.md - Builder\n\nYou are a coding agent.",
			expected: "Builder",
		},
		{
			name:     "You are bold format",
			content:  "# SOUL.md\n\nYou are **Scout** — the recon specialist.",
			expected: "Scout",
		},
		{
			name:     "no name found",
			content:  "# Some random content\n\nNothing useful here.",
			expected: "",
		},
		{
			name:     "empty content",
			content:  "",
			expected: "",
		},
		{
			name:     "both patterns present, header first",
			content:  "# SOUL.md - HeaderName\n\nYou are **BoldName** — agent",
			expected: "HeaderName",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := extractNameFromSoul(tt.content)
			if result != tt.expected {
				t.Errorf("extractNameFromSoul() = %q, want %q", result, tt.expected)
			}
		})
	}
}

func TestSplitLines(t *testing.T) {
	tests := []struct {
		input    string
		expected int
	}{
		{"a\nb\nc", 3},
		{"single", 1},
		{"", 0},
		{"a\n", 1},
		{"a\nb\n", 2},
	}

	for _, tt := range tests {
		lines := splitLines(tt.input)
		if len(lines) != tt.expected {
			t.Errorf("splitLines(%q) = %d lines, want %d", tt.input, len(lines), tt.expected)
		}
	}
}

func TestIndexOf(t *testing.T) {
	tests := []struct {
		s, substr string
		expected  int
	}{
		{"hello world", "world", 6},
		{"hello", "xyz", -1},
		{"abcabc", "abc", 0},
		{"", "x", -1},
		{"x", "", 0},
	}

	for _, tt := range tests {
		result := indexOf(tt.s, tt.substr)
		if result != tt.expected {
			t.Errorf("indexOf(%q, %q) = %d, want %d", tt.s, tt.substr, result, tt.expected)
		}
	}
}

func TestResolveModelDisplay(t *testing.T) {
	tests := []struct {
		name     string
		model    interface{}
		expected string
	}{
		{
			name:     "nil model",
			model:    nil,
			expected: "default",
		},
		{
			name:     "empty string",
			model:    "",
			expected: "default",
		},
		{
			name:     "simple string",
			model:    "claude-opus-4-6",
			expected: "claude-opus-4-6",
		},
		{
			name:     "provider/model string",
			model:    "anthropic/claude-sonnet-4-6",
			expected: "claude-sonnet-4-6",
		},
		{
			name:     "map with primary",
			model:    map[string]interface{}{"primary": "openai-codex/gpt-5.4"},
			expected: "gpt-5.4",
		},
		{
			name:     "map without primary",
			model:    map[string]interface{}{"fallbacks": []string{"x"}},
			expected: "default",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := ResolveModelDisplay(tt.model)
			if result != tt.expected {
				t.Errorf("ResolveModelDisplay() = %q, want %q", result, tt.expected)
			}
		})
	}
}

func TestParseModelString(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"openai-codex/gpt-5.4", "gpt-5.4"},
		{"anthropic/claude-sonnet-4-6", "claude-sonnet-4-6"},
		{"claude-opus-4-6", "claude-opus-4-6"},
		{"", ""},
	}

	for _, tt := range tests {
		result := parseModelString(tt.input)
		if result != tt.expected {
			t.Errorf("parseModelString(%q) = %q, want %q", tt.input, result, tt.expected)
		}
	}
}
