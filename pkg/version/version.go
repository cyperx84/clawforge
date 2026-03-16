package version

// Version is set at build time via ldflags:
// go build -ldflags "-X github.com/cyperx84/clawforge/pkg/version.Version=3.0.0"
var Version = "dev"
