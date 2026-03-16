package remote

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"strings"
)

// Remote represents a remote OpenClaw instance
type Remote struct {
	Name string `json:"name"`
	Host string `json:"host"` // user@host format
}

// RemotesConfig holds all remotes
type RemotesConfig struct {
	Remotes []Remote `json:"remotes"`
}

func remotesPath() (string, error) {
	u, err := user.Current()
	if err != nil {
		return "", err
	}
	return filepath.Join(u.HomeDir, ".clawforge", "remotes.json"), nil
}

// ReadRemotes reads the remotes config
func ReadRemotes() (*RemotesConfig, error) {
	path, err := remotesPath()
	if err != nil {
		return nil, err
	}

	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return &RemotesConfig{}, nil
		}
		return nil, err
	}

	var cfg RemotesConfig
	if err := json.Unmarshal(data, &cfg); err != nil {
		return nil, fmt.Errorf("failed to parse remotes config: %w", err)
	}
	return &cfg, nil
}

// WriteRemotes writes the remotes config
func WriteRemotes(cfg *RemotesConfig) error {
	path, err := remotesPath()
	if err != nil {
		return err
	}

	os.MkdirAll(filepath.Dir(path), 0755)

	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0644)
}

// AddRemote adds a new remote
func AddRemote(name, host string) error {
	cfg, err := ReadRemotes()
	if err != nil {
		return err
	}

	// Check for duplicate
	for _, r := range cfg.Remotes {
		if r.Name == name {
			return fmt.Errorf("remote already exists: %s", name)
		}
	}

	cfg.Remotes = append(cfg.Remotes, Remote{Name: name, Host: host})
	return WriteRemotes(cfg)
}

// RemoveRemote removes a remote by name
func RemoveRemote(name string) error {
	cfg, err := ReadRemotes()
	if err != nil {
		return err
	}

	idx := -1
	for i, r := range cfg.Remotes {
		if r.Name == name {
			idx = i
			break
		}
	}
	if idx == -1 {
		return fmt.Errorf("remote not found: %s", name)
	}

	cfg.Remotes = append(cfg.Remotes[:idx], cfg.Remotes[idx+1:]...)
	return WriteRemotes(cfg)
}

// GetRemote returns a remote by name
func GetRemote(name string) (*Remote, error) {
	cfg, err := ReadRemotes()
	if err != nil {
		return nil, err
	}

	for _, r := range cfg.Remotes {
		if r.Name == name {
			return &r, nil
		}
	}
	return nil, fmt.Errorf("remote not found: %s", name)
}

// ListRemotes returns all configured remotes
func ListRemotes() ([]Remote, error) {
	cfg, err := ReadRemotes()
	if err != nil {
		return nil, err
	}
	return cfg.Remotes, nil
}

// RunRemoteStatus runs `clawforge list` on a remote via SSH
func RunRemoteStatus(name string) (string, error) {
	remote, err := GetRemote(name)
	if err != nil {
		return "", err
	}

	cmd := exec.Command("ssh", remote.Host, "clawforge", "list")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("SSH command failed: %w\n%s", err, string(output))
	}
	return strings.TrimSpace(string(output)), nil
}

// FormatRemoteList returns a human-readable list of remotes
func FormatRemoteList(remotes []Remote) string {
	if len(remotes) == 0 {
		return "No remotes configured.\n"
	}

	var s string
	s += fmt.Sprintf("%-15s %s\n", "NAME", "HOST")
	s += strings.Repeat("-", 40) + "\n"
	for _, r := range remotes {
		s += fmt.Sprintf("%-15s %s\n", r.Name, r.Host)
	}
	return s
}
