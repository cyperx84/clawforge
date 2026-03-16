.PHONY: build test lint clean install release help

# Version
VERSION := 0.1.0
BINARY := clawforge
LDFLAGS := -ldflags "-X github.com/cyperx84/clawforge/cmd.Version=$(VERSION)"

help:
	@echo "ClawForge Build Targets"
	@echo "======================"
	@echo "make build      - Build the binary"
	@echo "make test       - Run tests"
	@echo "make lint       - Run linters"
	@echo "make clean      - Remove build artifacts"
	@echo "make install    - Install binary to /usr/local/bin"
	@echo "make release    - Build release for all platforms (requires goreleaser)"

build:
	go build $(LDFLAGS) -o bin/$(BINARY) .

test:
	go test ./... -v -cover

lint:
	@command -v golangci-lint >/dev/null 2>&1 || echo "golangci-lint not found. Install with: brew install golangci-lint"
	golangci-lint run ./...

clean:
	rm -rf bin/ dist/
	go clean

install: build
	cp bin/$(BINARY) /usr/local/bin/$(BINARY)
	@echo "Installed to /usr/local/bin/$(BINARY)"

release:
	@command -v goreleaser >/dev/null 2>&1 || (echo "goreleaser not found. Install with: brew install goreleaser" && exit 1)
	goreleaser release --clean

release-snapshot:
	goreleaser release --snapshot --clean

.PHONY: version
version:
	@echo "ClawForge version $(VERSION)"
