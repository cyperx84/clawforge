package cmd

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/cyperx84/clawforge/internal/fleet"
)

var (
	syncFix  bool
	syncJSON bool
)

var syncCmd = &cobra.Command{
	Use:   "sync",
	Short: "Detect drift between disk agents and config",
	Long: `Detect drift between ~/.openclaw/agents/ disk directories and
~/.openclaw/openclaw.json configuration.

Shows agents on disk but not in config, and agents in config but not on disk.
Use --fix to auto-add disk agents to config.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		result, err := fleet.DetectDrift()
		if err != nil {
			return err
		}

		if syncJSON {
			jsonStr, err := fleet.FormatSyncJSON(result)
			if err != nil {
				return err
			}
			fmt.Println(jsonStr)
			return nil
		}

		fmt.Print(fleet.FormatSyncResult(result))

		if syncFix && len(result.DiskOnly) > 0 {
			added, err := fleet.FixDrift(result)
			if err != nil {
				return fmt.Errorf("fix failed: %w", err)
			}
			fmt.Printf("\n✓ Added %d agent(s) to config.\n", added)
		} else if len(result.DiskOnly) > 0 {
			fmt.Printf("\nRun with --fix to auto-add disk agents to config.\n")
		}

		return nil
	},
}

func init() {
	syncCmd.Flags().BoolVar(&syncFix, "fix", false, "Auto-add disk agents to config")
	syncCmd.Flags().BoolVar(&syncJSON, "json", false, "Machine-readable JSON output")
}
