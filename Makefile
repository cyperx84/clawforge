.PHONY: build test lint clean install release help

VERSION := $(shell cat VERSION 2>/dev/null || echo "dev")
BINARY  := clawforge
LDFLAGS := -ldflags "-s -w -X github.com/cyperx84/clawforge/cmd.Version=$(VERSION)"

help:
	@echo "ClawForge Build Targets"
	@echo "======================"
	@echo "make build            - Build the binary"
	@echo "make test             - Run tests"
	@echo "make lint             - Run linters"
	@echo "make clean            - Remove build artifacts"
	@echo "make install          - Install to /usr/local/bin"
	@echo "make release          - Goreleaser cross-platform release"
	@echo "make release-snapshot - Goreleaser snapshot (no publish)"

build:
	@mkdir -p bin
	go build $(LDFLAGS) -o bin/$(BINARY) .

test:
	go test ./... -v -cover

lint:
	@command -v golangci-lint >/dev/null 2>&1 || { echo "golangci-lint not found: brew install golangci-lint"; exit 1; }
	golangci-lint run ./...

clean:
	rm -rf bin/ dist/
	go clean

install: build
	cp bin/$(BINARY) /usr/local/bin/$(BINARY)
	@echo "Installed $(VERSION) → /usr/local/bin/$(BINARY)"

release:
	@command -v goreleaser >/dev/null 2>&1 || { echo "goreleaser not found: brew install goreleaser"; exit 1; }
	goreleaser release --clean

release-snapshot:
	goreleaser release --snapshot --clean

version:
	@echo "$(VERSION)"
