#!/usr/bin/env bash
set -euo pipefail

mkdir -p /var/log/naver-mcp

exec mcp-proxy --host 0.0.0.0 --port 8080 --pass-environment -- \
  /usr/bin/env bash -lc 'node /usr/src/app/dist/src/index.js 2> >(tee -a /var/log/naver-mcp/app.log >&2)'

