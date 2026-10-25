# Multi-stage build: builder compiles a static Go binary; runtime is a minimal distroless image.

# ── Stage 1: Build ─────────────────────────────────────────────────────────────
FROM registry.gitlab.com/hzahnlei/build-images/go-build:1.4.3 AS builder

ARG VERSION=dev
ARG COMMIT=unknown

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build \
        -ldflags="-s -w -X main.version=${VERSION} -X main.commit=${COMMIT}" \
        -o /install/go-tool \
        ./cmd/go-tool/...

# Debug-capable variant: same flags minus -s -w, so the symbol table and DWARF debug info
# are retained for dlv/pprof. Same optimization level and behavior as the release build —
# not the sanitizer-enabled Debug build configuration.
RUN CGO_ENABLED=0 GOOS=linux go build \
        -ldflags="-X main.version=${VERSION} -X main.commit=${COMMIT}" \
        -o /install/debug/go-tool \
        ./cmd/go-tool/...

# ── Stage 2: Production runtime (distroless, no shell) ─────────────────────────
FROM gcr.io/distroless/static-debian13:nonroot AS release

COPY --from=builder /install/go-tool /app/go-tool

ENTRYPOINT ["/app/go-tool"]

# ── Stage 3: Debug runtime (debug-symbol binary + investigation tooling) ───────
# Not distroless: the investigation tools need a package manager.
FROM debian:13.5-slim AS debug

# Investigation tools for an engineer inside the container (containerization guideline).
COPY --from=mikefarah/yq:4.54.1 /usr/bin/yq /usr/local/bin/yq
RUN apt-get update -qq && \
    apt-get upgrade -y -qq && \
    apt-get install -y --no-install-recommends ca-certificates curl jq procps ripgrep vim-tiny && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=builder /install/debug/go-tool /app/go-tool
COPY image/entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
