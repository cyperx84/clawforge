package main

import (
	"embed"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

//go:embed index.html
var indexHTML embed.FS

type Task struct {
	ID          string  `json:"id"`
	ShortID     int     `json:"short_id"`
	Description string  `json:"description"`
	Status      string  `json:"status"`
	Mode        string  `json:"mode"`
	Agent       string  `json:"agent"`
	Model       string  `json:"model"`
	Branch      string  `json:"branch"`
	Repo        string  `json:"repo"`
	Worktree    string  `json:"worktree"`
	StartedAt   int64   `json:"startedAt"`
	Cost        float64 `json:"cost,omitempty"`
	TmuxSession string  `json:"tmuxSession"`
	Effort      string  `json:"effort"`
	HooksFired  bool    `json:"hooks_fired"`
}

type Registry struct {
	Tasks []Task `json:"tasks"`
}

type DashboardData struct {
	Tasks     []Task        `json:"tasks"`
	Stats     Stats         `json:"stats"`
	Uptime    string        `json:"uptime"`
	Timestamp int64         `json:"timestamp"`
}

type Stats struct {
	Total    int     `json:"total"`
	Running  int     `json:"running"`
	Done     int     `json:"done"`
	Failed   int     `json:"failed"`
	Spawned  int     `json:"spawned"`
	Cost     float64 `json:"totalCost"`
}

var (
	clawforgeDir string
	startTime    time.Time
)

func init() {
	// Find clawforge directory
	exe, _ := os.Executable()
	clawforgeDir = filepath.Dir(filepath.Dir(exe))

	// Also check env
	if dir := os.Getenv("CLAWFORGE_DIR"); dir != "" {
		clawforgeDir = dir
	}

	startTime = time.Now()
}

func readRegistry() (*Registry, error) {
	path := filepath.Join(clawforgeDir, "registry", "active-tasks.json")
	data, err := os.ReadFile(path)
	if err != nil {
		return &Registry{Tasks: []Task{}}, nil
	}

	var reg Registry
	if err := json.Unmarshal(data, &reg); err != nil {
		return &Registry{Tasks: []Task{}}, nil
	}
	return &reg, nil
}

func calcStats(tasks []Task) Stats {
	s := Stats{Total: len(tasks)}
	for _, t := range tasks {
		switch t.Status {
		case "running":
			s.Running++
		case "done":
			s.Done++
		case "failed", "timeout":
			s.Failed++
		case "spawned":
			s.Spawned++
		}
		s.Cost += t.Cost
	}
	return s
}

func handleAPI(w http.ResponseWriter, r *http.Request) {
	reg, _ := readRegistry()

	uptime := time.Since(startTime).Round(time.Second).String()

	data := DashboardData{
		Tasks:     reg.Tasks,
		Stats:     calcStats(reg.Tasks),
		Uptime:    uptime,
		Timestamp: time.Now().Unix(),
	}

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	json.NewEncoder(w).Encode(data)
}

func handleTaskPreview(w http.ResponseWriter, r *http.Request) {
	id := r.URL.Query().Get("id")
	if id == "" {
		http.Error(w, "id required", 400)
		return
	}

	// Try to capture tmux output
	session := fmt.Sprintf("agent-%s", id)
	reg, _ := readRegistry()
	for _, t := range reg.Tasks {
		if t.ID == id || fmt.Sprintf("%d", t.ShortID) == id {
			if t.TmuxSession != "" {
				session = t.TmuxSession
			}
			break
		}
	}

	out, err := exec.Command("tmux", "capture-pane", "-t", session, "-p", "-S", "-30").Output()
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"preview": "(no tmux output available)"})
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"preview": string(out)})
}

func handleIndex(w http.ResponseWriter, r *http.Request) {
	data, _ := indexHTML.ReadFile("index.html")
	w.Header().Set("Content-Type", "text/html")
	w.Write(data)
}

func main() {
	port := "9876"
	if len(os.Args) > 1 {
		port = strings.TrimPrefix(os.Args[1], "--port=")
		port = strings.TrimPrefix(port, "-p=")
		if p := os.Getenv("PORT"); p != "" {
			port = p
		}
	}
	if p := os.Getenv("PORT"); p != "" {
		port = p
	}

	http.HandleFunc("/", handleIndex)
	http.HandleFunc("/api/dashboard", handleAPI)
	http.HandleFunc("/api/preview", handleTaskPreview)

	fmt.Printf("🔧 ClawForge Dashboard: http://localhost:%s\n", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
