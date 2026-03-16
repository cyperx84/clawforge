package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"

	"github.com/cyperx84/clawforge/internal/mcp"
)

var mcpCmd = &cobra.Command{
	Use:   "mcp",
	Short: "Run as an MCP server over stdio",
	Long: `Run ClawForge as a Model Context Protocol (MCP) server over stdio.

This allows MCP clients like Claude Code, Codex, and other tools to manage
your agent fleet through standard MCP tool calls.

Example MCP client config (claude_desktop_config.json):
  {
    "mcpServers": {
      "clawforge": {
        "command": "clawforge",
        "args": ["mcp"]
      }
    }
  }

The server reads JSON-RPC messages from stdin and writes responses to stdout.
Logs are written to stderr.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		binary, err := os.Executable()
		if err != nil {
			binary = "clawforge"
		}

		fmt.Fprintln(os.Stderr, "clawforge: MCP server starting")
		srv := mcp.NewServer(Version, binary)
		return srv.Run()
	},
}
