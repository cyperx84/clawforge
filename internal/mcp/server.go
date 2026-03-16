package mcp

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strconv"
	"strings"
)

// JSON-RPC types

type Request struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id,omitempty"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params,omitempty"`
}

type Response struct {
	JSONRPC string      `json:"jsonrpc"`
	ID      json.RawMessage `json:"id,omitempty"`
	Result  interface{} `json:"result,omitempty"`
	Error   *RPCError   `json:"error,omitempty"`
}

type RPCError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

// MCP types

type ServerInfo struct {
	Name    string `json:"name"`
	Version string `json:"version"`
}

type InitializeResult struct {
	ProtocolVersion string            `json:"protocolVersion"`
	Capabilities    map[string]interface{} `json:"capabilities"`
	ServerInfo      ServerInfo        `json:"serverInfo"`
}

type Tool struct {
	Name        string      `json:"name"`
	Description string      `json:"description"`
	InputSchema InputSchema `json:"inputSchema"`
}

type InputSchema struct {
	Type       string                 `json:"type"`
	Properties map[string]Property    `json:"properties"`
	Required   []string               `json:"required,omitempty"`
}

type Property struct {
	Type        string `json:"type"`
	Description string `json:"description"`
}

type ToolsListResult struct {
	Tools []Tool `json:"tools"`
}

type ToolCallParams struct {
	Name      string                 `json:"name"`
	Arguments map[string]interface{} `json:"arguments"`
}

type ContentItem struct {
	Type string `json:"type"`
	Text string `json:"text"`
}

type ToolCallResult struct {
	Content []ContentItem `json:"content"`
	IsError bool          `json:"isError,omitempty"`
}

// Server

type Server struct {
	version string
	binary  string
	in      io.Reader
	out     io.Writer
	errLog  io.Writer
}

func NewServer(version, binary string) *Server {
	return &Server{
		version: version,
		binary:  binary,
		in:      os.Stdin,
		out:     os.Stdout,
		errLog:  os.Stderr,
	}
}

// NewServerWithIO creates a server with custom I/O for testing.
func NewServerWithIO(version, binary string, in io.Reader, out io.Writer, errLog io.Writer) *Server {
	return &Server{
		version: version,
		binary:  binary,
		in:      in,
		out:     out,
		errLog:  errLog,
	}
}

func (s *Server) Run() error {
	scanner := bufio.NewScanner(s.in)
	// Allow large lines (1MB)
	scanner.Buffer(make([]byte, 0, 1024*1024), 1024*1024)

	for scanner.Scan() {
		line := scanner.Text()
		if strings.TrimSpace(line) == "" {
			continue
		}

		var req Request
		if err := json.Unmarshal([]byte(line), &req); err != nil {
			s.writeError(nil, -32700, "Parse error")
			continue
		}

		// Notifications (no id) — ignore silently
		if req.ID == nil {
			s.handleNotification(req)
			continue
		}

		resp := s.handleRequest(req)
		s.writeResponse(resp)
	}

	return scanner.Err()
}

func (s *Server) handleNotification(req Request) {
	// MCP notifications like notifications/initialized — no response needed
	fmt.Fprintf(s.errLog, "mcp: notification %s\n", req.Method)
}

func (s *Server) handleRequest(req Request) Response {
	switch req.Method {
	case "initialize":
		return s.handleInitialize(req)
	case "tools/list":
		return s.handleToolsList(req)
	case "tools/call":
		return s.handleToolsCall(req)
	case "ping":
		return Response{JSONRPC: "2.0", ID: req.ID, Result: map[string]interface{}{}}
	default:
		return Response{
			JSONRPC: "2.0",
			ID:      req.ID,
			Error:   &RPCError{Code: -32601, Message: fmt.Sprintf("Method not found: %s", req.Method)},
		}
	}
}

func (s *Server) handleInitialize(req Request) Response {
	return Response{
		JSONRPC: "2.0",
		ID:      req.ID,
		Result: InitializeResult{
			ProtocolVersion: "2024-11-05",
			Capabilities:    map[string]interface{}{"tools": map[string]interface{}{}},
			ServerInfo:      ServerInfo{Name: "clawforge", Version: s.version},
		},
	}
}

func (s *Server) handleToolsList(req Request) Response {
	return Response{
		JSONRPC: "2.0",
		ID:      req.ID,
		Result:  ToolsListResult{Tools: toolDefinitions()},
	}
}

func (s *Server) handleToolsCall(req Request) Response {
	var params ToolCallParams
	if err := json.Unmarshal(req.Params, &params); err != nil {
		return Response{
			JSONRPC: "2.0",
			ID:      req.ID,
			Error:   &RPCError{Code: -32602, Message: "Invalid params"},
		}
	}

	output, err := s.executeTool(params.Name, params.Arguments)
	if err != nil {
		return Response{
			JSONRPC: "2.0",
			ID:      req.ID,
			Result: ToolCallResult{
				Content: []ContentItem{{Type: "text", Text: err.Error()}},
				IsError: true,
			},
		}
	}

	return Response{
		JSONRPC: "2.0",
		ID:      req.ID,
		Result: ToolCallResult{
			Content: []ContentItem{{Type: "text", Text: output}},
		},
	}
}

func (s *Server) executeTool(name string, args map[string]interface{}) (string, error) {
	switch name {
	case "fleet_list":
		return s.run("list", "--json")
	case "fleet_status":
		return s.run("status", "--json")
	case "fleet_deploy":
		return s.runDeploy(args)
	case "fleet_inspect":
		return s.runWithID(args, "inspect", "--json")
	case "fleet_health":
		return s.run("health", "--json")
	case "fleet_sync":
		return s.runSync(args)
	case "fleet_logs":
		return s.runLogs(args)
	case "fleet_diff":
		return s.runDiff(args)
	case "fleet_destroy":
		return s.runWithID(args, "destroy")
	default:
		return "", fmt.Errorf("unknown tool: %s", name)
	}
}

func (s *Server) run(cmdArgs ...string) (string, error) {
	cmd := exec.Command(s.binary, cmdArgs...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("%s: %s", err, string(out))
	}
	return string(out), nil
}

func (s *Server) runWithID(args map[string]interface{}, cmdArgs ...string) (string, error) {
	id, ok := args["id"].(string)
	if !ok || id == "" {
		return "", fmt.Errorf("required parameter: id")
	}
	fullArgs := append(cmdArgs[:1], id)
	fullArgs = append(fullArgs, cmdArgs[1:]...)
	return s.run(fullArgs...)
}

func (s *Server) runDeploy(args map[string]interface{}) (string, error) {
	id, ok := args["id"].(string)
	if !ok || id == "" {
		return "", fmt.Errorf("required parameter: id")
	}
	cmdArgs := []string{"deploy", id}
	if v, ok := args["from"].(string); ok && v != "" {
		cmdArgs = append(cmdArgs, "--from", v)
	}
	if v, ok := args["name"].(string); ok && v != "" {
		cmdArgs = append(cmdArgs, "--name", v)
	}
	if v, ok := args["role"].(string); ok && v != "" {
		cmdArgs = append(cmdArgs, "--role", v)
	}
	if v, ok := args["emoji"].(string); ok && v != "" {
		cmdArgs = append(cmdArgs, "--emoji", v)
	}
	if v, ok := args["channel"].(string); ok && v != "" {
		cmdArgs = append(cmdArgs, "--channel", v)
	}
	return s.run(cmdArgs...)
}

func (s *Server) runSync(args map[string]interface{}) (string, error) {
	cmdArgs := []string{"sync", "--json"}
	if fix, ok := args["fix"].(bool); ok && fix {
		cmdArgs = append(cmdArgs, "--fix")
	}
	return s.run(cmdArgs...)
}

func (s *Server) runLogs(args map[string]interface{}) (string, error) {
	id, ok := args["id"].(string)
	if !ok || id == "" {
		return "", fmt.Errorf("required parameter: id")
	}
	cmdArgs := []string{"logs", id}
	if tail, ok := args["tail"].(float64); ok && tail > 0 {
		cmdArgs = append(cmdArgs, "--tail", strconv.Itoa(int(tail)))
	}
	return s.run(cmdArgs...)
}

func (s *Server) runDiff(args map[string]interface{}) (string, error) {
	id1, ok := args["id1"].(string)
	if !ok || id1 == "" {
		return "", fmt.Errorf("required parameter: id1")
	}
	id2, ok := args["id2"].(string)
	if !ok || id2 == "" {
		return "", fmt.Errorf("required parameter: id2")
	}
	cmdArgs := []string{"diff", id1, id2}
	if files, ok := args["files"].(bool); ok && files {
		cmdArgs = append(cmdArgs, "--files")
	}
	return s.run(cmdArgs...)
}

func (s *Server) writeResponse(resp Response) {
	data, err := json.Marshal(resp)
	if err != nil {
		fmt.Fprintf(s.errLog, "mcp: marshal error: %v\n", err)
		return
	}
	fmt.Fprintf(s.out, "%s\n", data)
}

func (s *Server) writeError(id json.RawMessage, code int, message string) {
	resp := Response{
		JSONRPC: "2.0",
		ID:      id,
		Error:   &RPCError{Code: code, Message: message},
	}
	s.writeResponse(resp)
}

// Tool definitions

func toolDefinitions() []Tool {
	return []Tool{
		{
			Name:        "fleet_list",
			Description: "List all agents in the fleet",
			InputSchema: InputSchema{
				Type:       "object",
				Properties: map[string]Property{},
			},
		},
		{
			Name:        "fleet_status",
			Description: "Show fleet-wide status overview",
			InputSchema: InputSchema{
				Type:       "object",
				Properties: map[string]Property{},
			},
		},
		{
			Name:        "fleet_deploy",
			Description: "Deploy a new agent (create + bind + activate)",
			InputSchema: InputSchema{
				Type: "object",
				Properties: map[string]Property{
					"id":      {Type: "string", Description: "Agent ID to deploy"},
					"from":    {Type: "string", Description: "Archetype to deploy from"},
					"name":    {Type: "string", Description: "Agent display name"},
					"role":    {Type: "string", Description: "Agent role description"},
					"emoji":   {Type: "string", Description: "Agent emoji"},
					"channel": {Type: "string", Description: "Channel to bind to"},
				},
				Required: []string{"id"},
			},
		},
		{
			Name:        "fleet_inspect",
			Description: "Inspect a specific agent's configuration and workspace",
			InputSchema: InputSchema{
				Type: "object",
				Properties: map[string]Property{
					"id": {Type: "string", Description: "Agent ID to inspect"},
				},
				Required: []string{"id"},
			},
		},
		{
			Name:        "fleet_health",
			Description: "Show live health status for all agents",
			InputSchema: InputSchema{
				Type:       "object",
				Properties: map[string]Property{},
			},
		},
		{
			Name:        "fleet_sync",
			Description: "Detect and optionally fix drift between disk and config",
			InputSchema: InputSchema{
				Type: "object",
				Properties: map[string]Property{
					"fix": {Type: "boolean", Description: "Auto-fix detected drift"},
				},
			},
		},
		{
			Name:        "fleet_logs",
			Description: "Show recent logs for an agent",
			InputSchema: InputSchema{
				Type: "object",
				Properties: map[string]Property{
					"id":   {Type: "string", Description: "Agent ID"},
					"tail": {Type: "integer", Description: "Number of recent log lines to show"},
				},
				Required: []string{"id"},
			},
		},
		{
			Name:        "fleet_diff",
			Description: "Compare configuration and workspace of two agents",
			InputSchema: InputSchema{
				Type: "object",
				Properties: map[string]Property{
					"id1":   {Type: "string", Description: "First agent ID"},
					"id2":   {Type: "string", Description: "Second agent ID"},
					"files": {Type: "boolean", Description: "Include file-level diff"},
				},
				Required: []string{"id1", "id2"},
			},
		},
		{
			Name:        "fleet_destroy",
			Description: "Destroy an agent (remove config, workspace, and bindings)",
			InputSchema: InputSchema{
				Type: "object",
				Properties: map[string]Property{
					"id": {Type: "string", Description: "Agent ID to destroy"},
				},
				Required: []string{"id"},
			},
		},
	}
}
