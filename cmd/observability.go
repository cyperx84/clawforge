package cmd

import (
	"fmt"
	"strings"

	"github.com/spf13/cobra"

	"github.com/cyperx84/clawforge/internal/observability"
)

var statusCmd = &cobra.Command{
	Use:   "status [id]",
	Short: "Show agent or fleet status",
	Long:  `Display the health and status of agents.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		if len(args) == 0 {
			// Fleet status
			statuses, err := observability.GetFleetStatus()
			if err != nil {
				return err
			}

			if len(statuses) == 0 {
				fmt.Println("No agents found.")
				return nil
			}

			fmt.Printf("%-15s %-20s %-12s %-25s %-10s %-10s\n",
				"ID", "NAME", "STATUS", "MODEL", "MEMORY", "BINDINGS")
			fmt.Println(strings.Repeat("-", 100))
			for _, s := range statuses {
				fmt.Printf("%-15s %-20s %-12s %-25s %-10d %-10d\n",
					s.ID, s.Name, s.Status, s.Model, s.MemoryFiles, s.Bindings)
			}
		} else {
			// Agent status
			status, err := observability.GetAgentStatus(args[0])
			if err != nil {
				return err
			}

			fmt.Printf("Agent: %s\n", status.ID)
			fmt.Printf("Name: %s\n", status.Name)
			fmt.Printf("Status: %s\n", status.Status)
			fmt.Printf("Model: %s\n", status.Model)
			fmt.Printf("Bindings: %d\n", status.Bindings)
			fmt.Printf("Memory Files: %d\n", status.MemoryFiles)
			fmt.Printf("Reference Files: %d\n", status.ReferenceFiles)
		}
		return nil
	},
}

var costCmd = &cobra.Command{
	Use:   "cost [id]",
	Short: "Show cost information",
	Long:  `Display cost tracking for agents.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		summary, err := observability.GetCostSummary()
		if err != nil {
			return err
		}

		fmt.Printf("Total Cost: $%.2f\n", summary.Total)
		fmt.Printf("Today: $%.2f\n", summary.Today)
		fmt.Printf("This Week: $%.2f\n", summary.Week)

		if len(summary.ByAgent) > 0 {
			fmt.Println("\nBy Agent:")
			for agent, cost := range summary.ByAgent {
				fmt.Printf("  %s: $%.2f\n", agent, cost)
			}
		}

		return nil
	},
}

var logsCmd = &cobra.Command{
	Use:   "logs <id>",
	Short: "View agent logs",
	Long:  `Display recent logs for an agent.`,
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		id := args[0]

		logs, err := observability.GetAgentLogs(id, 20)
		if err != nil {
			return err
		}

		if len(logs) == 0 {
			fmt.Printf("No logs found for agent: %s\n", id)
			return nil
		}

		for _, log := range logs {
			fmt.Printf("[%s] %s: %s\n", log.Timestamp.Format("15:04:05"), log.Level, log.Message)
		}

		return nil
	},
}

func init() {
	costCmd.Flags().String("period", "total", "Period: today, week, month, total")
	logsCmd.Flags().Bool("follow", false, "Follow logs (watch for new entries)")
	logsCmd.Flags().Int("tail", 20, "Number of log lines to show")
}
