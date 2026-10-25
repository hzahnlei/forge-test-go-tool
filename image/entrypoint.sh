#!/usr/bin/env bash
set -euo pipefail

# Entrypoint for the debug container image, which has bash and investigation tools.
# The production image (release stage) runs the binary directly without this script.
exec /app/go-tool "$@"
