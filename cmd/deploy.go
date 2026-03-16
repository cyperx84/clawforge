package cmd

import (
	"fmt"
	"os/exec"

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

Creates the agent workspace, writes it to openclaw.json, optionally binds
to a Discord channel, and restarts the gateway if openclaw binary exists.`,
	Args: cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		id := args[0]

		// Determine name
		name := deployName
		if name == "" {
			name = id
		}

		// Determine model
		model := agentModel
		if model == "" {
			model = "claude-opus-4-6"
		}

		agent := &config.Agent{
			ID:    id,
			Name:  name,
			Role:  deployRole,
			Emoji: deployEmoji,
			Model: model,
		}

		// Step 1: Create agent in config
		fmt.Printf("Creating agent %s...\n", id)
		if err := fleet.CreateAgent(agent); err != nil {
			return fmt.Errorf("create failed: %w", err)
		}

		// Step 2: Create workspace
		workspace, err := fleet.CreateWorkspace(id)
		if err != nil {
			fleet.DeleteAgent(id)
			return fmt.Errorf("workspace creation failed: %w", err)
		}

		// Step 3: Apply archetype if specified
		if deployFrom != "" {
			arch, err := fleet.GetArchetype(deployFrom)
			if err != nil {
				fleet.DeleteAgent(id)
				fleet.DeleteWorkspace(id)
				return fmt.Errorf("archetype failed: %w", err)
			}
			for filename, template := range arch.Templates {
				content := fleet.SubstitutePlaceholders(
					template, name, deployRole, deployEmoji,
					fmt.Sprintf("Agent with role: %s", deployRole),
					fmt.Sprintf("%v", model),
				)
				if err := fleet.WriteWorkspaceFile(id, filename, content); err != nil {
					return err
				}
			}
			fmt.Printf("  Applied archetype: %s\n", deployFrom)
		}

		// Step 4: Update workspace path in config
		agent.Workspace = workspace
		fleet.UpdateAgent(agent)

		// Step 5: Bind to channel if specified
		if deployChannel != "" {
			if err := fleet.BindDiscord(id, deployChannel, ""); err != nil {
				return fmt.Errorf("bind failed: %w", err)
			}
			fmt.Printf("  Bound to Discord channel: %s\n", deployChannel)
		}

		// Step 6: Restart gateway if openclaw binary exists
		if _, err := exec.LookPath("openclaw"); err == nil {
			fmt.Println("  Restarting OpenClaw gateway...")
			restartCmd := exec.Command("openclaw", "gateway", "restart")
			if output, err := restartCmd.CombinedOutput(); err != nil {
				fmt.Printf("  Warning: gateway restart failed: %v\n%s\n", err, string(output))
			} else {
				fmt.Println("  Gateway restarted successfully.")
			}
		}

		fmt.Printf("\n✓ Deployed agent: %s (%s)\n", id, name)
		fmt.Printf("  Workspace: %s\n", workspace)
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
