package cmd

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/cyperx84/clawforge/internal/observability"
)

var healthJSON bool

var healthCmd = &cobra.Command{
	Use:   "health [id]",
	Short: "Show live agent health",
	Long: `Show live agent health from OpenClaw session data.

Reads HEARTBEAT.md and session directories to determine agent health,
last active time, session count, and error indicators.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		if len(args) > 0 {
			// Single agent health
			h, err := observability.GetAgentHealth(args[0])
			if err != nil {
				return err
			}
			healths := []observability.AgentHealth{*h}

			if healthJSON {
				jsonStr, err := observability.FormatHealthJSON(healths)
				if err != nil {
					return err
				}
				fmt.Println(jsonStr)
				return nil
			}

			fmt.Print(observability.FormatHealth(healths))
			return nil
		}

		// Fleet health
		healths, err := observability.GetFleetHealth()
		if err != nil {
			return err
		}

		if healthJSON {
			jsonStr, err := observability.FormatHealthJSON(healths)
			if err != nil {
				return err
			}
			fmt.Println(jsonStr)
			return nil
		}

		fmt.Print(observability.FormatHealth(healths))
		return nil
	},
}

func init() {
	healthCmd.Flags().BoolVar(&healthJSON, "json", false, "Machine-readable JSON output")
}
