package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

// Version is injected at build time via ldflags
var Version = "dev"

var rootCmd = &cobra.Command{
	Use:   "clawforge",
	Short: "ClawForge — Multi-agent orchestration CLI & TUI",
	Long:  `ClawForge is a complete rewrite of the ClawForge bash suite as a single Go binary with a Bubble Tea TUI.`,
	Run: func(cmd *cobra.Command, args []string) {
		cmd.Help()
	},
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func init() {
	// Add subcommands
	rootCmd.AddCommand(versionCmd)
	rootCmd.AddCommand(createCmd)
	rootCmd.AddCommand(listCmd)
	rootCmd.AddCommand(inspectCmd)
	rootCmd.AddCommand(editCmd)
	rootCmd.AddCommand(cloneCmd)
	rootCmd.AddCommand(destroyCmd)
	rootCmd.AddCommand(activateCmd)
	rootCmd.AddCommand(deactivateCmd)
	rootCmd.AddCommand(bindCmd)
	rootCmd.AddCommand(unbindCmd)
	rootCmd.AddCommand(exportCmd)
	rootCmd.AddCommand(importCmd)
	rootCmd.AddCommand(statusCmd)
	rootCmd.AddCommand(costCmd)
	rootCmd.AddCommand(logsCmd)
	rootCmd.AddCommand(templateCmd)
	rootCmd.AddCommand(configCmd)
	rootCmd.AddCommand(doctorCmd)
	rootCmd.AddCommand(completionCmd)
	rootCmd.AddCommand(tuiCmd)
	rootCmd.AddCommand(syncCmd)
	rootCmd.AddCommand(healthCmd)
	rootCmd.AddCommand(deployCmd)
	rootCmd.AddCommand(diffCmd)
	rootCmd.AddCommand(remoteCmd)
}

var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Print ClawForge version",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Printf("ClawForge version %s\n", Version)
	},
}
