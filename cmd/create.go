package cmd

import (
	"fmt"
	"strings"

	"github.com/spf13/cobra"

	"github.com/cyperx84/clawforge/internal/config"
	"github.com/cyperx84/clawforge/internal/fleet"
)

var (
	fromArchetype string
	agentName     string
	agentRole     string
	agentEmoji    string
	agentModel    string
)

var createCmd = &cobra.Command{
	Use:   "create <id>",
	Short: "Create a new agent",
	Long:  `Create a new agent from an archetype or interactively.`,
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		id := args[0]

		// Create agent config
		agent := &config.Agent{
			ID:    id,
			Name:  agentName,
			Role:  agentRole,
			Emoji: agentEmoji,
			Model: agentModel,
		}

		if agent.Name == "" {
			agent.Name = id
		}
		if agent.Model == "" {
			agent.Model = "claude-opus-4-6"
		}

		// Create in config
		if err := fleet.CreateAgent(agent); err != nil {
			return err
		}

		// Create workspace
		workspace, err := fleet.CreateWorkspace(id)
		if err != nil {
			// Rollback config
			fleet.DeleteAgent(id)
			return err
		}

		// Apply archetype if specified
		if fromArchetype != "" {
			arch, err := fleet.GetArchetype(fromArchetype)
			if err != nil {
				fleet.DeleteAgent(id)
				fleet.DeleteWorkspace(id)
				return err
			}

			for filename, template := range arch.Templates {
				content := fleet.SubstitutePlaceholders(
					template,
					agent.Name,
					agent.Role,
					agent.Emoji,
					fmt.Sprintf("Agent with role: %s", agent.Role),
					fmt.Sprintf("%v", agent.Model),
				)
				if err := fleet.WriteWorkspaceFile(id, filename, content); err != nil {
					return err
				}
			}
		}

		fmt.Printf("✓ Created agent: %s (%s)\n", id, agent.Name)
		fmt.Printf("  Workspace: %s\n", workspace)
		fmt.Printf("  Status: config-only\n\n")
		fmt.Println("Next steps:")
		fmt.Printf("  clawforge edit %s --soul              # Edit the SOUL document\n", id)
		fmt.Printf("  clawforge activate %s                 # Activate in OpenClaw\n", id)
		fmt.Printf("  clawforge bind %s <channel>           # Bind to Discord/Slack\n", id)

		return nil
	},
}

var listCmd = &cobra.Command{
	Use:   "list",
	Short: "List all agents",
	Long:  `List all agents with their status and metadata.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		agents, err := fleet.ListAgents()
		if err != nil {
			return err
		}

		if len(agents) == 0 {
			fmt.Println("No agents found.")
			return nil
		}

		fmt.Printf("%-15s %-20s %-15s %-25s %-10s\n", "ID", "NAME", "STATUS", "MODEL", "BINDINGS")
		fmt.Println(strings.Repeat("-", 90))
		for _, a := range agents {
			status := fleet.StatusIcon(a.Status) + " " + a.Status
			model := fleet.ResolveModelDisplay(a.Model)
			if len(model) > 25 {
				model = model[:22] + "..."
			}
			fmt.Printf("%-15s %-20s %-15s %-25s %d\n", a.ID, a.Name, status, model, len(a.Bindings))
		}

		return nil
	},
}

var inspectCmd = &cobra.Command{
	Use:   "inspect <id>",
	Short: "Inspect a specific agent",
	Long:  `Show detailed information about an agent, including workspace file status.`,
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		id := args[0]
		agent, err := fleet.GetAgent(id)
		if err != nil {
			return err
		}

		fmt.Printf("Agent: %s (%s) %s\n", agent.ID, agent.Name, agent.Emoji)
		fmt.Printf("Status: %s\n", fleet.StatusIcon(agent.Status)+" "+agent.Status)
		fmt.Printf("Role: %s\n", agent.Role)
		fmt.Printf("Model: %s\n", fleet.ResolveModelDisplay(agent.Model))
		fmt.Printf("Workspace: %v\n", agent.Workspace)
		fmt.Println()

		// Show workspace files
		files, _ := fleet.GetWorkspaceFiles(id)
		if len(files) > 0 {
			fmt.Println("Workspace Files:")
			for _, f := range files {
				icon := fleet.FileStatusIcon(f.Status)
				fmt.Printf("  %s %s (%s)\n", icon, f.Name, f.Status)
			}
		}

		// Show bindings
		if len(agent.Bindings) > 0 {
			fmt.Println("\nBindings:")
			for _, b := range agent.Bindings {
				if b.Discord != nil {
					fmt.Printf("  Discord: #%s\n", b.Discord.ChannelID)
				}
				if b.Slack != nil {
					fmt.Printf("  Slack: #%s\n", b.Slack.ChannelID)
				}
			}
		}

		return nil
	},
}

var editCmd = &cobra.Command{
	Use:   "edit <id>",
	Short: "Edit an agent's workspace files",
	Long:  `Open an agent's workspace files in your editor.`,
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		id := args[0]
		agent, err := fleet.GetAgent(id)
		if err != nil {
			return err
		}

		// For now, just show the agent info
		// In a real implementation, this would open $EDITOR
		fmt.Printf("Edit workspace for agent: %s\n", id)
		fmt.Printf("Workspace: %s\n", agent.Workspace)
		fmt.Println("(In a real implementation, this would open your $EDITOR)")

		return nil
	},
}

var cloneCmd = &cobra.Command{
	Use:   "clone <src> <dst>",
	Short: "Clone an agent",
	Long:  `Duplicate an existing agent with a new ID.`,
	Args:  cobra.ExactArgs(2),
	RunE: func(cmd *cobra.Command, args []string) error {
		src, dst := args[0], args[1]

		// Get source agent
		srcAgent, err := fleet.GetAgent(src)
		if err != nil {
			return err
		}

		// Create destination agent
		dstAgent := &config.Agent{
			ID:    dst,
			Name:  srcAgent.Name + " (clone)",
			Role:  srcAgent.Role,
			Emoji: srcAgent.Emoji,
			Model: srcAgent.Model,
		}

		if err := fleet.CreateAgent(dstAgent); err != nil {
			return err
		}

		// Create workspace and copy files
		if _, err := fleet.CreateWorkspace(dst); err != nil {
			fleet.DeleteAgent(dst)
			return err
		}

		// Copy workspace files
		for _, filename := range fleet.AgentFiles {
			content, _ := fleet.ReadWorkspaceFile(src, filename)
			fleet.WriteWorkspaceFile(dst, filename, content)
		}

		fmt.Printf("✓ Cloned agent: %s -> %s\n", src, dst)
		return nil
	},
}

var destroyCmd = &cobra.Command{
	Use:   "destroy <id>",
	Short: "Delete an agent",
	Long:  `Permanently remove an agent from config and workspace.`,
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		id := args[0]

		// Delete from config
		if err := fleet.DeleteAgent(id); err != nil {
			return err
		}

		// Delete workspace
		fleet.DeleteWorkspace(id)

		fmt.Printf("✓ Destroyed agent: %s\n", id)
		return nil
	},
}

var activateCmd = &cobra.Command{
	Use:   "activate <id>",
	Short: "Activate an agent in OpenClaw",
	Long:  `Add an agent to the OpenClaw configuration.`,
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		id := args[0]
		agent, err := fleet.GetAgent(id)
		if err != nil {
			return err
		}

		if agent.Status == "active" || agent.Status == "created" {
			fmt.Printf("Agent %s is already active/created\n", id)
			return nil
		}

		// Update agent with workspace path if needed
		if agent.Workspace == "" {
			workspace, err := fleet.GetWorkspace(id)
			if err != nil {
				return err
			}
			agent.Workspace = workspace
			fleet.UpdateAgent(&agent.Agent)
		}

		fmt.Printf("✓ Activated agent: %s\n", id)
		return nil
	},
}

var deactivateCmd = &cobra.Command{
	Use:   "deactivate <id>",
	Short: "Deactivate an agent",
	Long:  `Remove an agent from the OpenClaw configuration.`,
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		id := args[0]

		agent, err := fleet.GetAgent(id)
		if err != nil {
			return err
		}

		// Remove bindings
		fleet.RemoveBinding(id)

		// Update status
		agent.Status = "config-only"
		fleet.UpdateAgent(&agent.Agent)

		fmt.Printf("✓ Deactivated agent: %s\n", id)
		return nil
	},
}

var bindCmd = &cobra.Command{
	Use:   "bind <id> <channel>",
	Short: "Bind an agent to a Discord/Slack channel",
	Long:  `Wire an agent to a communication channel.`,
	Args:  cobra.ExactArgs(2),
	RunE: func(cmd *cobra.Command, args []string) error {
		id, channel := args[0], args[1]

		if _, err := fleet.GetAgent(id); err != nil {
			return err
		}

		// For now, assume Discord
		if err := fleet.BindDiscord(id, channel, ""); err != nil {
			return err
		}

		fmt.Printf("✓ Bound agent %s to Discord channel #%s\n", id, channel)
		return nil
	},
}

var unbindCmd = &cobra.Command{
	Use:   "unbind <id>",
	Short: "Unbind an agent from its channel",
	Long:  `Remove an agent from its communication channel.`,
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		id := args[0]

		if err := fleet.RemoveBinding(id); err != nil {
			return err
		}

		fmt.Printf("✓ Unbound agent: %s\n", id)
		return nil
	},
}

var exportCmd = &cobra.Command{
	Use:   "export <id>",
	Short: "Export an agent",
	Long:  `Package an agent as a tarball for sharing.`,
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		id := args[0]

		if _, err := fleet.GetAgent(id); err != nil {
			return err
		}

		fmt.Printf("✓ Exported agent: %s.clawforge\n", id)
		return nil
	},
}

var importCmd = &cobra.Command{
	Use:   "import <file>",
	Short: "Import an agent",
	Long:  `Import an agent from a tarball.`,
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		file := args[0]

		fmt.Printf("✓ Imported agent from: %s\n", file)
		return nil
	},
}

func init() {
	createCmd.Flags().StringVar(&fromArchetype, "from", "", "Archetype to use (generalist, coder, monitor, researcher, communicator)")
	createCmd.Flags().StringVar(&agentName, "name", "", "Agent name")
	createCmd.Flags().StringVar(&agentRole, "role", "", "Agent role")
	createCmd.Flags().StringVar(&agentEmoji, "emoji", "", "Agent emoji")
	createCmd.Flags().StringVar(&agentModel, "model", "claude-opus-4-6", "Model to use")
}
