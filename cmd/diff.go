package cmd

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/cyperx84/clawforge/internal/fleet"
)

var (
	diffFiles bool
	diffJSON  bool
)

var diffCmd = &cobra.Command{
	Use:   "diff <id1> <id2>",
	Short: "Compare two agents' configs and workspace files",
	Long: `Compare two agents side by side.

Shows config differences (model, role, emoji, bindings) and
workspace file summaries (line count, key sections).
Use --files to show full diff of workspace files.`,
	Args: cobra.ExactArgs(2),
	RunE: func(cmd *cobra.Command, args []string) error {
		id1, id2 := args[0], args[1]

		result, err := fleet.CompareAgents(id1, id2, diffFiles)
		if err != nil {
			return err
		}

		if diffJSON {
			jsonStr, err := fleet.FormatDiffJSON(result)
			if err != nil {
				return err
			}
			fmt.Println(jsonStr)
			return nil
		}

		fmt.Print(fleet.FormatDiff(result))
		return nil
	},
}

func init() {
	diffCmd.Flags().BoolVar(&diffFiles, "files", false, "Show full diff of workspace files")
	diffCmd.Flags().BoolVar(&diffJSON, "json", false, "Machine-readable JSON output")
}
