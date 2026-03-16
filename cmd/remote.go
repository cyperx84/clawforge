package cmd

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/cyperx84/clawforge/internal/remote"
)

var remoteCmd = &cobra.Command{
	Use:   "remote",
	Short: "Manage remote OpenClaw instances",
	Long:  `List, add, remove, and inspect agents on remote OpenClaw instances via SSH.`,
	Run: func(cmd *cobra.Command, args []string) {
		cmd.Help()
	},
}

var remoteAddCmd = &cobra.Command{
	Use:   "add <name> <user@host>",
	Short: "Add a remote OpenClaw instance",
	Args:  cobra.ExactArgs(2),
	RunE: func(cmd *cobra.Command, args []string) error {
		name, host := args[0], args[1]
		if err := remote.AddRemote(name, host); err != nil {
			return err
		}
		fmt.Printf("✓ Added remote: %s (%s)\n", name, host)
		return nil
	},
}

var remoteListCmd = &cobra.Command{
	Use:   "list",
	Short: "List configured remotes",
	RunE: func(cmd *cobra.Command, args []string) error {
		remotes, err := remote.ListRemotes()
		if err != nil {
			return err
		}
		fmt.Print(remote.FormatRemoteList(remotes))
		return nil
	},
}

var remoteRemoveCmd = &cobra.Command{
	Use:   "remove <name>",
	Short: "Remove a remote",
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		name := args[0]
		if err := remote.RemoveRemote(name); err != nil {
			return err
		}
		fmt.Printf("✓ Removed remote: %s\n", name)
		return nil
	},
}

var remoteStatusCmd = &cobra.Command{
	Use:   "status <name>",
	Short: "Show agent status on a remote instance",
	Long:  `Run 'clawforge list' on the remote OpenClaw instance via SSH.`,
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		name := args[0]
		output, err := remote.RunRemoteStatus(name)
		if err != nil {
			return err
		}
		fmt.Println(output)
		return nil
	},
}

func init() {
	remoteCmd.AddCommand(remoteAddCmd)
	remoteCmd.AddCommand(remoteListCmd)
	remoteCmd.AddCommand(remoteRemoveCmd)
	remoteCmd.AddCommand(remoteStatusCmd)
}
