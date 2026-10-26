ARTIFACT     := go-tool
BUILD_DIR    := build
REPORTS_DIR  := test_reports
MKDOCS_IMAGE := registry.gitlab.com/hzahnlei/build-images/mkdocs:1.5.3

# Every recipe gets bash's -e/-u/pipefail semantics for free
# instead of each one declaring it: a failing command aborts the recipe immediately, an unset
# variable is an error, and a failing command inside a pipe is no longer silently swallowed by
# the pipe's last command's exit code.
SHELL         := bash
.SHELLFLAGS   := -eu -o pipefail -c

VERSION    := $(shell git describe --tags --always --dirty 2>/dev/null || echo "0.0.0")
COMMIT     := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_TIME := $(shell date -u +%Y-%m-%dT%H:%M:%SZ)

.PHONY: phony

all: build

# Download dependencies and update go.sum. Run once after cloning or after changing go.mod.
init: phony
	go mod tidy

VERSION_LDFLAGS := \
  -X main.version=$(VERSION) \
  -X main.commit=$(COMMIT) \
  -X main.buildTime=$(BUILD_TIME)

# `build` collides with $(BUILD_DIR) (both named "build"), and this recipe really does write into
# it. No target here currently depends on `build`, but if one ever does, comparing build/'s own
# directory mtime (which doesn't necessarily change just because files deep inside it do) against
# that target's mtime could make it silently skip its recipe while still reporting success — see
# build_cpp.tmpl for the case where exactly that already happened.
.PHONY: build

# Debug build: debug symbols, no optimizations. Named -debug, so the release build never replaces
# it. Statically linked (CGO disabled) so the binary stays portable across whichever image consumes
# it downstream — same reasoning as release-build.
build: phony
	mkdir -p $(BUILD_DIR)
	CGO_ENABLED=0 go build -gcflags="all=-N -l" -ldflags="$(VERSION_LDFLAGS)" \
	    -o $(BUILD_DIR)/$(ARTIFACT)-debug ./cmd/$(ARTIFACT)

# Release build: stripped binary, statically linked (CGO disabled).
release-build: phony
	mkdir -p $(BUILD_DIR)
	CGO_ENABLED=0 go build -ldflags="-s -w $(VERSION_LDFLAGS)" \
	    -o $(BUILD_DIR)/$(ARTIFACT) ./cmd/$(ARTIFACT)

# Run the debug build. Arguments can be passed via ARGS: make run ARGS="--help"
run: phony
	$(BUILD_DIR)/$(ARTIFACT)-debug $(ARGS)

# Run the unit tests with race detector; run go vet for static analysis. The BDD scenarios in
# test/bdd/ run in `bdd-test`.
# go-junit-report converts go test -json output to JUnit XML for CI integration.
# Install: go install github.com/jstemmer/go-junit-report/v2@latest
test: phony
	mkdir -p $(REPORTS_DIR)/test
	go vet ./...
	go test -race -count=1 -v -json $$(go list ./... | grep -v '/test/bdd$$') \
	    | go-junit-report -iocopy -out $(REPORTS_DIR)/test/test_results.xml

# Measure code coverage of the tests and the BDD scenarios together. -coverpkg counts every test
# for every package of the module, so a scenario in test/bdd counts for the packages it reaches.
# cmd/ is excluded: by convention it is thin wiring that delegates to domain/usecase/infra/app —
# counting it would penalize exactly the "thin entrypoint" style the architecture calls for.
# A scenario that starts the built executable gets one built with -cover (see test/bdd), which
# writes its counts into covdata/; they join the tests' profile, without cmd/, before the figure
# is computed.
# gocover-cobertura converts Go coverage output to Cobertura XML for CI integration.
# Install: go install github.com/boumenot/gocover-cobertura@latest
COVER_PKGS = $(shell go list ./... | grep -vE '/cmd($$|/)|/test/bdd$$' | paste -sd, -)

coverage: phony
	rm -rf $(REPORTS_DIR)/coverage
	mkdir -p $(REPORTS_DIR)/coverage/covdata
	BDD_COVERDIR=$(CURDIR)/$(REPORTS_DIR)/coverage/covdata go test -race -count=1 \
	    -coverpkg=$(COVER_PKGS) \
	    -coverprofile=$(REPORTS_DIR)/coverage/coverage.out \
	    -covermode=atomic \
	    $$(go list ./... | grep -vE '/cmd($$|/)')
	if [ -n "$$(ls -A $(REPORTS_DIR)/coverage/covdata)" ]; then \
	  go tool covdata textfmt -i=$(REPORTS_DIR)/coverage/covdata -pkg=$(COVER_PKGS) \
	    -o $(REPORTS_DIR)/coverage/scenarios.out; \
	  tail -n +2 $(REPORTS_DIR)/coverage/scenarios.out >> $(REPORTS_DIR)/coverage/coverage.out; \
	fi
	go tool cover -html=$(REPORTS_DIR)/coverage/coverage.out \
	    -o $(REPORTS_DIR)/coverage/coverage.html
	gocover-cobertura < $(REPORTS_DIR)/coverage/coverage.out \
	    > $(REPORTS_DIR)/coverage/coverage.xml
	@PCT=$$(go tool cover -func=$(REPORTS_DIR)/coverage/coverage.out | tail -1 | awk '{gsub(/%/,""); print $$NF}'); \
	echo "Coverage: $$PCT%"; \
	awk -v p="$$PCT" 'BEGIN { if (p+0 < 80) { print "FAIL: coverage " p "% is below the 80% minimum"; exit 1 } }'

# Run the Godog scenarios in test/bdd/. `test` leaves them out; `coverage` includes them.
bdd-test: phony
	mkdir -p $(REPORTS_DIR)/bdd-test
	go test -race -count=1 -v -json ./test/bdd/... \
	    | go-junit-report -iocopy -out $(REPORTS_DIR)/bdd-test/test_results.xml

# Enforce Clean Architecture layer dependencies (app → infra → usecase → domain).
# go-arch-lint reads .go-arch-lint.yml and fails on any violation.
# Install: go install github.com/fe3dback/go-arch-lint@latest
arch-test: phony
	mkdir -p $(REPORTS_DIR)/arch-test
	go-arch-lint check > $(REPORTS_DIR)/arch-test/go-arch-lint.txt 2>&1 || STATUS=$$?; \
	  cat $(REPORTS_DIR)/arch-test/go-arch-lint.txt || true; exit "$${STATUS:-0}"

# Run golangci-lint (includes go vet, staticcheck, and more).
# Writes a Checkstyle XML report to $(REPORTS_DIR)/linting/ for CI artifact collection.
lint-code: phony
	mkdir -p $(REPORTS_DIR)/linting
	golangci-lint run \
	    --output.checkstyle.path $(REPORTS_DIR)/linting/golangci-lint.xml \
	    ./...

# Lint every shell script in the project with ShellCheck from the image the CI pipeline uses.
# Scripts are discovered rather than hardcoded, since which ones exist (container entrypoints,
# Claude hooks, scripts/*.sh) varies by project type — every one of them must still pass. `+`
# batches all matches into one shellcheck invocation and, unlike `$$(find ...)`, runs the command
# zero times (exit 0) instead of blocking on stdin when nothing matches.
SHELL_TOOLS_IMAGE := registry.gitlab.com/hzahnlei/build-images/shell-tools:1.2.1

# In the pipeline, the job already runs in that image.
ifdef CI
SHELL_TOOLS_FIND := find
else
SHELL_TOOLS_FIND := docker run --rm -v "$(CURDIR):/workdir" -w /workdir --entrypoint find $(SHELL_TOOLS_IMAGE)
endif

lint-shell: phony
	mkdir -p $(REPORTS_DIR)/linting
	$(SHELL_TOOLS_FIND) \
	    . -type f -name "*.sh" -not -path "./$(BUILD_DIR)/*" -not -path "./.git/*" -not -path "./node_modules/*" -not -path "./.devbox/*" \
	    -not -path "./.go-cache/*" -not -path "./.npm-cache/*" -not -path "./.m2/*" -not -path "./.conan/*" \
	    -exec shellcheck {} + > $(REPORTS_DIR)/linting/shellcheck.txt 2>&1 || STATUS=$$?; \
	  cat $(REPORTS_DIR)/linting/shellcheck.txt; exit "$${STATUS:-0}"

# Check every DBC file with cantools from the image the CI pipeline uses: loading fails on
# a syntax error, on signals that overlap or reach beyond their message, and on a message identifier
# or name used twice. The image exists for amd64 only. Without a DBC file, there is nothing to check.
CANTOOLS_IMAGE := registry.gitlab.com/hzahnlei/build-images/cantools:1.0.1

# In the pipeline, the job already runs in that image.
ifdef CI
CANTOOLS_FIND := find
else
CANTOOLS_FIND := docker run --rm --platform linux/amd64 -v "$(CURDIR):/workdir" -w /workdir --entrypoint find $(CANTOOLS_IMAGE)
endif

lint-dbc: phony
	$(CANTOOLS_FIND) \
	    . -type f -name "*.dbc" -not -path "./$(BUILD_DIR)/*" -not -path "./.git/*" -exec sh -c \
	    'status=0; for f; do cantools dump "$$f" > /dev/null || { echo "$$f: not a valid DBC file" >&2; status=1; }; done; exit "$$status"' \
	    sh {} +

# Run every linter of the project.
lint: lint-code lint-shell lint-markdown lint-dbc

# Lint every Markdown file with markdownlint-cli2 from the image the CI pipeline uses;
# .markdownlint-cli2.jsonc names the files and .markdownlint.json the rules.
MARKDOWNLINT_IMAGE := davidanson/markdownlint-cli2:v0.23.3

lint-markdown: phony
	mkdir -p $(REPORTS_DIR)/linting
	docker run --rm -v "$(CURDIR):/workdir" -w /workdir $(MARKDOWNLINT_IMAGE) \
	    > $(REPORTS_DIR)/linting/markdownlint.txt 2>&1 || STATUS=$$?; \
	  cat $(REPORTS_DIR)/linting/markdownlint.txt; exit "$${STATUS:-0}"

# Lint the GitHub Actions workflows.
ci-lint: phony
	actionlint

# Scan repository for secrets and vulnerabilities with Trivy.
scan: phony
	docker run --rm \
	    -v "$(CURDIR):/workdir" \
	    -w /workdir \
	    aquasec/trivy:0.74.0 \
	    fs --exit-code 1 --severity HIGH,CRITICAL --scanners secret,vuln .

IMAGE_REGISTRY ?= ghcr.io/hzahnlei
IMAGE_NAME     := $(IMAGE_REGISTRY)/$(ARTIFACT)
# The build images exist for amd64 only, and so do the images.
IMAGE_PLATFORM := linux/amd64

# The images take what the builds produced, as in the pipeline, and compile nothing themselves.
# Locally, the builds run in the pipeline's build images first, into a directory of their own, so
# that they never replace the host's executables.
IMAGE_BUILD_DIR := $(BUILD_DIR)/image
IMAGE_BUILD_RUN := docker run --rm --platform $(IMAGE_PLATFORM) -v "$(CURDIR):/src" -w /src \
    -u "$$(id -u):$$(id -g)" -e HOME=/tmp \
    -e GIT_CONFIG_COUNT=1 -e GIT_CONFIG_KEY_0=safe.directory -e GIT_CONFIG_VALUE_0='*'

# Defensive: `image` collides with the real image/ directory (holds the Dockerfile, present from
# generation time, not just after a build) — no target here currently depends on `image`, but if
# one ever does, comparing image/'s own directory mtime against that target's would risk silently
# skipping its recipe (see build_cpp.tmpl for the case where this already bit a target with its
# own recipe).
.PHONY: image

# Debug container image (bash and investigation tools, see the containerization guideline).
# Image name is suffixed with -debug to distinguish from the release image.
image: phony
	$(IMAGE_BUILD_RUN) -e GOCACHE=/src/.go-cache/build -e GOMODCACHE=/src/.go-cache/mod registry.gitlab.com/hzahnlei/build-images/go-build:1.4.3 \
	    make build BUILD_DIR=$(IMAGE_BUILD_DIR) VERSION=$(VERSION) COMMIT=$(COMMIT)
	docker build \
	    --platform $(IMAGE_PLATFORM) \
	    --build-arg DEBUG_EXECUTABLE=$(IMAGE_BUILD_DIR)/$(ARTIFACT)-debug \
	    --target debug \
	    -t $(IMAGE_NAME):$(VERSION)-debug \
	    -f image/Dockerfile .

# Release container image (distroless, nonroot — minimal attack surface).
# Tagged with both the version and latest.
release-image: phony
	$(IMAGE_BUILD_RUN) -e GOCACHE=/src/.go-cache/build -e GOMODCACHE=/src/.go-cache/mod registry.gitlab.com/hzahnlei/build-images/go-build:1.4.3 \
	    make release-build BUILD_DIR=$(IMAGE_BUILD_DIR) VERSION=$(VERSION) COMMIT=$(COMMIT)
	docker build \
	    --platform $(IMAGE_PLATFORM) \
	    --build-arg RELEASE_EXECUTABLE=$(IMAGE_BUILD_DIR)/$(ARTIFACT) \
	    --target release \
	    -t $(IMAGE_NAME):$(VERSION) \
	    -t $(IMAGE_NAME):latest \
	    -f image/Dockerfile .

# Scan the release container image for secrets and vulnerabilities with Trivy.
# Two passes, matching the CI job: report everything, then fail only on what has a fix
# available — an unfixed vulnerability cannot be resolved from this repository.
scan-image: phony
	docker run --rm \
	    aquasec/trivy:0.74.0 \
	    image --severity HIGH,CRITICAL --exit-code 0 $(IMAGE_NAME):$(VERSION)
	docker run --rm \
	    aquasec/trivy:0.74.0 \
	    image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 $(IMAGE_NAME):$(VERSION)

# Generate documentation locally with live-reload at http://localhost:8000.
# mkdocs.yml must exist in the repository root. Runs in a named container so `docs-down` can
# always find and stop it, even if Ctrl+C didn't cleanly stop it (the mkdocs image's entrypoint
# doesn't reliably forward SIGINT/SIGTERM to the mkdocs process).
DOCS_CONTAINER := $(ARTIFACT)-docs

docs: phony
	docker run --rm \
	           --name $(DOCS_CONTAINER) \
	           -v "$(CURDIR):/docs" \
	           -p 8000:8000 \
	           $(MKDOCS_IMAGE) serve --dev-addr=0.0.0.0:8000

# Stop a docs server left running in the background (e.g. after Ctrl+C didn't stop it cleanly).
docs-down: phony
	docker stop $(DOCS_CONTAINER) 2>/dev/null || true

# Stop any existing docs server, then start a fresh one.
docs-restart: docs-down docs

# Build the documentation site into SITE_DIR with the mkdocs image the pipeline uses. In the
# pipeline, the job already runs in that image.
SITE_DIR ?= site
ifdef CI
MKDOCS := /usr/local/bin/entrypoint.sh
else
MKDOCS := docker run --rm -v "$(CURDIR):/docs" $(MKDOCS_IMAGE)
endif

docs-build: phony
	$(MKDOCS) build --site-dir $(SITE_DIR)

# Delete all generated build artifacts and test reports.
clean: phony
	rm -rf $(BUILD_DIR) $(REPORTS_DIR)

# This file is generator owned. User defined targets go here:
include Makefile.local

