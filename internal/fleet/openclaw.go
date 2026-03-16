package fleet

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"
)

// openclawBin returns the path to the openclaw CLI
func openclawBin() string {
	if path, err := exec.LookPath("openclaw"); err == nil {
		return path
	}
	return "openclaw"
}

// runOpenClaw executes an openclaw CLI command and returns stdout
func runOpenClaw(args ...string) (string, error) {
	cmd := exec.Command(openclawBin(), args...)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return string(out), fmt.Errorf("openclaw %s failed: %w\n%s", strings.Join(args, " "), err, string(out))
	}
	return string(out), nil
}

// OpenClawAgentAdd adds an agent via `openclaw agents add`
func OpenClawAgentAdd(id, name, model, workspace string) error {
	args := []string{"agents", "add", name, "--non-interactive", "--json"}
	if model != "" {
		args = append(args, "--model", model)
	}
	if workspace != "" {
		args = append(args, "--workspace", workspace)
	}
	out, err := runOpenClaw(args...)
	if err != nil {
		return err
	}

	// Verify the result
	var result map[string]interface{}
	if jsonErr := json.Unmarshal([]byte(out), &result); jsonErr == nil {
		if errMsg, ok := result["error"].(string); ok {
			return fmt.Errorf("openclaw agents add: %s", errMsg)
		}
	}
	return nil
}

// OpenClawAgentDelete removes an agent via `openclaw agents delete`
func OpenClawAgentDelete(id string) error {
	_, err := runOpenClaw("agents", "delete", id, "--force", "--json")
	return err
}

// OpenClawAgentBind binds an agent to a channel via `openclaw agents bind`
func OpenClawAgentBind(agentID, channel string) error {
	_, err := runOpenClaw("agents", "bind", "--agent", agentID, "--bind", channel, "--json")
	return err
}

// OpenClawAgentUnbind removes bindings for an agent via `openclaw agents unbind`
func OpenClawAgentUnbind(agentID string) error {
	_, err := runOpenClaw("agents", "unbind", "--agent", agentID, "--json")
	return err
}
