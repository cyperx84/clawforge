package mcp

import (
	"bytes"
	"encoding/json"
	"io"
	"strings"
	"testing"
)

func runServer(t *testing.T, input string) []Response {
	t.Helper()
	in := strings.NewReader(input)
	var out bytes.Buffer
	errLog := io.Discard

	srv := NewServerWithIO("3.1.1", "clawforge", in, &out, errLog)
	if err := srv.Run(); err != nil {
		t.Fatalf("server.Run() error: %v", err)
	}

	var responses []Response
	for _, line := range strings.Split(strings.TrimSpace(out.String()), "\n") {
		if line == "" {
			continue
		}
		var resp Response
		if err := json.Unmarshal([]byte(line), &resp); err != nil {
			t.Fatalf("unmarshal response %q: %v", line, err)
		}
		responses = append(responses, resp)
	}
	return responses
}

func TestInitialize(t *testing.T) {
	input := `{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}` + "\n"
	responses := runServer(t, input)

	if len(responses) != 1 {
		t.Fatalf("expected 1 response, got %d", len(responses))
	}

	resp := responses[0]
	if resp.Error != nil {
		t.Fatalf("unexpected error: %v", resp.Error)
	}

	// Re-marshal result to check fields
	data, _ := json.Marshal(resp.Result)
	var result InitializeResult
	if err := json.Unmarshal(data, &result); err != nil {
		t.Fatalf("unmarshal result: %v", err)
	}

	if result.ProtocolVersion != "2024-11-05" {
		t.Errorf("protocolVersion = %q, want %q", result.ProtocolVersion, "2024-11-05")
	}
	if result.ServerInfo.Name != "clawforge" {
		t.Errorf("serverInfo.name = %q, want %q", result.ServerInfo.Name, "clawforge")
	}
	if result.ServerInfo.Version != "3.1.1" {
		t.Errorf("serverInfo.version = %q, want %q", result.ServerInfo.Version, "3.1.1")
	}
}

func TestToolsList(t *testing.T) {
	input := `{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}
`
	responses := runServer(t, input)

	if len(responses) != 2 {
		t.Fatalf("expected 2 responses, got %d", len(responses))
	}

	resp := responses[1]
	if resp.Error != nil {
		t.Fatalf("unexpected error: %v", resp.Error)
	}

	data, _ := json.Marshal(resp.Result)
	var result ToolsListResult
	if err := json.Unmarshal(data, &result); err != nil {
		t.Fatalf("unmarshal result: %v", err)
	}

	expectedTools := []string{
		"fleet_list", "fleet_status", "fleet_deploy", "fleet_inspect",
		"fleet_health", "fleet_sync", "fleet_logs", "fleet_diff", "fleet_destroy",
	}

	if len(result.Tools) != len(expectedTools) {
		t.Fatalf("expected %d tools, got %d", len(expectedTools), len(result.Tools))
	}

	toolNames := make(map[string]bool)
	for _, tool := range result.Tools {
		toolNames[tool.Name] = true
	}

	for _, name := range expectedTools {
		if !toolNames[name] {
			t.Errorf("missing tool: %s", name)
		}
	}
}

func TestFleetListTool(t *testing.T) {
	// Create a mock script that simulates clawforge list --json
	mockBinary := "echo"
	input := `{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"fleet_list","arguments":{}}}` + "\n"

	in := strings.NewReader(input)
	var out bytes.Buffer

	srv := NewServerWithIO("3.1.1", mockBinary, in, &out, io.Discard)
	if err := srv.Run(); err != nil {
		t.Fatalf("server.Run() error: %v", err)
	}

	var resp Response
	if err := json.Unmarshal(out.Bytes(), &resp); err != nil {
		t.Fatalf("unmarshal response: %v", err)
	}

	if resp.Error != nil {
		t.Fatalf("unexpected error: %v", resp.Error)
	}

	// Re-marshal to check the result structure
	data, _ := json.Marshal(resp.Result)
	var result ToolCallResult
	if err := json.Unmarshal(data, &result); err != nil {
		t.Fatalf("unmarshal result: %v", err)
	}

	if len(result.Content) != 1 {
		t.Fatalf("expected 1 content item, got %d", len(result.Content))
	}
	if result.Content[0].Type != "text" {
		t.Errorf("content type = %q, want %q", result.Content[0].Type, "text")
	}
	if result.IsError {
		t.Error("expected isError to be false")
	}
}

func TestUnknownMethod(t *testing.T) {
	input := `{"jsonrpc":"2.0","id":1,"method":"unknown/method","params":{}}` + "\n"
	responses := runServer(t, input)

	if len(responses) != 1 {
		t.Fatalf("expected 1 response, got %d", len(responses))
	}

	resp := responses[0]
	if resp.Error == nil {
		t.Fatal("expected error response")
	}
	if resp.Error.Code != -32601 {
		t.Errorf("error code = %d, want -32601", resp.Error.Code)
	}
}

func TestPing(t *testing.T) {
	input := `{"jsonrpc":"2.0","id":1,"method":"ping","params":{}}` + "\n"
	responses := runServer(t, input)

	if len(responses) != 1 {
		t.Fatalf("expected 1 response, got %d", len(responses))
	}
	if responses[0].Error != nil {
		t.Fatalf("unexpected error: %v", responses[0].Error)
	}
}

func TestUnknownTool(t *testing.T) {
	input := `{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"nonexistent","arguments":{}}}` + "\n"
	responses := runServer(t, input)

	if len(responses) != 1 {
		t.Fatalf("expected 1 response, got %d", len(responses))
	}

	data, _ := json.Marshal(responses[0].Result)
	var result ToolCallResult
	json.Unmarshal(data, &result)

	if !result.IsError {
		t.Error("expected isError to be true for unknown tool")
	}
}
