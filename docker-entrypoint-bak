#!/bin/sh
set -e

mkdir -p /var/log/naver-mcp

# MCP(stdio) 실행을 mcp-proxy 뒤에 붙여서 SSE로 노출
# 자식 프로세스에게 NAVER_* env를 그대로 넘기기 위해 --pass-environment 사용
exec mcp-proxy --host 0.0.0.0 --port 8080 --pass-environment -- \
  /bin/sh -lc "node /usr/src/app/dist/src/index.js 2>&1 | tee -a /var/log/naver-mcp/app.log"

