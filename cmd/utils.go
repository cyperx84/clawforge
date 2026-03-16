package cmd

import (
	"fmt"
	"os"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/spf13/cobra"

	"github.com/cyperx84/clawforge/internal/config"
	"github.com/cyperx84/clawforge/internal/fleet"
	"github.com/cyperx84/clawforge/internal/tui"
)

var templateCmd = &cobra.Command{
	Use:   "template",
	Short: "Manage agent archetypes",
	Long:  `List, show, create, or delete agent templates.`,
}

var templateListCmd = &cobra.Command{
	Use:   "list",
	Short: "List available archetypes",
	RunE: func(cmd *cobra.Command, args []string) error {
		archetypes := fleet.ListArchetypes()
		fmt.Println("Available Archetypes:")
		for _, arch := range archetypes {
			fmt.Printf("  - %s\n", arch)
		}
		return nil
	},
}

var templateShowCmd = &cobra.Command{
	Use:   "show <name>",
	Short: "Show archetype details",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		arch, err := fleet.GetArchetype(args[0])
		if err != nil {
			return err
		}
		fmt.Printf("Archetype: %s\n", arch.Name)
		fmt.Printf("Description: %s\n", arch.Description)
		fmt.Printf("Default Model: %s\n", arch.DefaultModel)
		fmt.Println("\nTemplates:")
		for filename := range arch.Templates {
			fmt.Printf("  - %s\n", filename)
		}
		return nil
	},
}

var configCmd = &cobra.Command{
	Use:   "config",
	Short: "Manage configuration",
	Long:  `View or set ClawForge configuration.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		if len(args) == 0 {
			// Show all config
			cfg, err := config.ReadUserConfig()
			if err != nil {
				return err
			}
			fmt.Println("User Configuration (~/.clawforge/config.json):")
			if len(cfg.Fleet) == 0 {
				fmt.Println("  (empty)")
			} else {
				for k, v := range cfg.Fleet {
					fmt.Printf("  %s: %v\n", k, v)
				}
			}
		}
		return nil
	},
}

var doctorCmd = &cobra.Command{
	Use:   "doctor",
	Short: "Run system health checks",
	Long:  `Diagnose configuration and environment issues.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		fmt.Println("ClawForge Doctor")
		fmt.Printf("Version: %s\n\n", Version)

		issues := 0

		// Check OpenClaw config
		cfgPath, err := config.OpenClawConfigPath()
		if err == nil {
			if info, err := os.Stat(cfgPath); err == nil {
				fmt.Printf("✓ OpenClaw config found (%s, %d bytes)\n", cfgPath, info.Size())
			} else {
				fmt.Printf("✗ OpenClaw config not found at %s\n", cfgPath)
				issues++
			}
		}

		// Check agents directory
		agentsDir, err := config.AgentsDir()
		if err == nil {
			if _, err := os.Stat(agentsDir); err == nil {
				entries, _ := os.ReadDir(agentsDir)
				dirs := 0
				for _, e := range entries {
					if e.IsDir() {
						dirs++
					}
				}
				fmt.Printf("✓ Agents directory exists (%s, %d subdirs)\n", agentsDir, dirs)
			} else {
				fmt.Printf("⚠ Agents directory not found at %s (will be created)\n", agentsDir)
			}
		}

		// Check user config
		userCfgPath, err := config.UserConfigPath()
		if err == nil {
			if _, err := os.Stat(userCfgPath); err == nil {
				fmt.Printf("✓ User config found (%s)\n", userCfgPath)
			} else {
				fmt.Printf("⚠ User config not found at %s (optional)\n", userCfgPath)
			}
		}

		// Count and summarize agents
		agents, err := fleet.ListAgents()
		if err == nil {
			active, created, configOnly := 0, 0, 0
			for _, a := range agents {
				switch a.Status {
				case "active":
					active++
				case "created":
					created++
				case "config-only":
					configOnly++
				}
			}
			fmt.Printf("✓ Found %d agents (active: %d, created: %d, config-only: %d)\n",
				len(agents), active, created, configOnly)
		} else {
			fmt.Printf("✗ Failed to list agents: %v\n", err)
			issues++
		}

		// Check Go runtime
		fmt.Printf("✓ Binary: %s\n", os.Args[0])

		fmt.Println()
		if issues == 0 {
			fmt.Println("All systems operational!")
		} else {
			fmt.Printf("%d issue(s) found.\n", issues)
		}
		return nil
	},
}

var completionCmd = &cobra.Command{
	Use:   "completion [bash|zsh|fish]",
	Short: "Generate shell completion scripts",
	Long:  `Output shell completion script for the specified shell.`,
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		shell := args[0]
		switch shell {
		case "bash":
			rootCmd.GenBashCompletion(os.Stdout)
		case "zsh":
			rootCmd.GenZshCompletion(os.Stdout)
		case "fish":
			rootCmd.GenFishCompletion(os.Stdout, true)
		default:
			return fmt.Errorf("unsupported shell: %s", shell)
		}
		return nil
	},
}

var tuiCmd = &cobra.Command{
	Use:   "tui",
	Short: "Launch the interactive TUI",
	Long:  `Start the Bubble Tea terminal user interface.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		app := tui.NewApp()
		p := tea.NewProgram(app)
		_, err := p.Run()
		return err
	},
}

func init() {
	// Add template subcommands
	templateCmd.AddCommand(templateListCmd)
	templateCmd.AddCommand(templateShowCmd)
}
