package cmd

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/cyperx84/clawforge/internal/config"
	"github.com/cyperx84/clawforge/internal/fleet"
)

var (
	deployFrom    string
	deployName    string
	deployRole    string
	deployEmoji   string
	deployChannel string
)

var deployCmd = &cobra.Command{
	Use:   "deploy <id>",
	Short: "One-shot agent deploy: create + bind + activate",
	Long: `Streamline agent setup by combining create, bind, and activate in one command.

Creates the agent workspace, registers it via the openclaw CLI, optionally
binds to a Discord channel. The openclaw CLI handles config writes safely
and triggers gateway reload automatically.`,
	Args: cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		id := args[0]

		// Determine name
		name := deployName
		if name == "" {
			name = id
		}

		// Determine model — use the configured default, not a hardcoded value
		model := agentModel

		// Step 1: Create workspace first so we have the path
		fmt.Printf("Creating workspace for %s...\n", id)
		workspace, err := fleet.CreateWorkspace(id)
		if err != nil {
			return fmt.Errorf("workspace creation failed: %w", err)
		}

		// Step 2: Apply archetype if specified (before registering with openclaw)
		if deployFrom != "" {
			arch, archErr := fleet.GetArchetype(deployFrom)
			if archErr != nil {
				fleet.DeleteWorkspace(id)
				return fmt.Errorf("archetype failed: %w", archErr)
			}
			for filename, template := range arch.Templates {
				content := fleet.SubstitutePlaceholders(
					template, name, deployRole, deployEmoji,
					fmt.Sprintf("Agent with role: %s", deployRole),
					model,
				)
				if writeErr := fleet.WriteWorkspaceFile(id, filename, content); writeErr != nil {
					fleet.DeleteWorkspace(id)
					return writeErr
				}
			}
			fmt.Printf("  Applied archetype: %s\n", deployFrom)
		}

		// Step 3: Register agent via openclaw CLI (safe config write + auto reload)
		fmt.Printf("Registering agent %s...\n", id)
		agent := &config.Agent{
			ID:        id,
			Name:      name,
			Model:     model,
			Workspace: workspace,
		}
		if err := fleet.CreateAgent(agent); err != nil {
			fleet.DeleteWorkspace(id)
			return fmt.Errorf("create failed: %w", err)
		}

		// Step 4: Bind to channel if specified
		if deployChannel != "" {
			// Pass full channel spec to openclaw CLI
			if err := fleet.AddBinding(id, "discord:"+deployChannel); err != nil {
				fmt.Printf("  Warning: bind failed: %v\n", err)
			} else {
				fmt.Printf("  Bound to Discord channel: %s\n", deployChannel)
			}
		}

		fmt.Printf("\n✓ Deployed agent: %s (%s)\n", id, name)
		fmt.Printf("  Workspace: %s\n", workspace)
		if model != "" {
			fmt.Printf("  Model: %s\n", model)
		}
		if deployChannel != "" {
			fmt.Printf("  Channel: %s\n", deployChannel)
		}

		return nil
	},
}

func init() {
	deployCmd.Flags().StringVar(&deployFrom, "from", "", "Archetype to use (generalist, coder, monitor, researcher, communicator)")
	deployCmd.Flags().StringVar(&deployName, "name", "", "Agent name")
	deployCmd.Flags().StringVar(&deployRole, "role", "", "Agent role")
	deployCmd.Flags().StringVar(&deployEmoji, "emoji", "", "Agent emoji")
	deployCmd.Flags().StringVar(&deployChannel, "channel", "", "Discord channel ID to bind to")
}
