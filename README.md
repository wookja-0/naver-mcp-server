# Naver MCP Server – SSE 배포 가이드 (단일 Dockerfile)

단일 Dockerfile 하나로 빌드/실행하며, `NAVER_API_BASE_URL` 한 변수만으로 Naver API 또는 프록시를 지정합니다. 앱은 SSE 노출을 위해 컨테이너 내부에서 `mcp-proxy`를 사용합니다.

---

## 1) 환경변수

- `NAVER_API_BASE_URL` (필수): 기본 `https://openapi.naver.com`
  - 예) 프록시 사용: `http://<proxy-host>:<port>/naver`
- `NAVER_API_KEY` (필수, Secret 권장)
- `NAVER_CLIENT_ID` (필수, Secret 권장)
- `NAVER_CLIENT_SECRET` (필수, Secret 권장)
- `NAVER_PROFILE` (선택, 배포 프로파일 구분용. 예: `prod`, `dev`)
- `BRIDGE_PORT` (선택, 기본 8080)
- `NODE_ENV` (선택, 기본 production)

앱 내부에서는 `NAVER_API_BASE_URL` 뒤에 `/v1/search`, `/v1/datalab` 경로가 자동으로 붙습니다. 후행 `/`는 자동 제거됩니다.

### 환경변수 설정 예시

```bash
# 도커 실행 예시 (프록시 사용 케이스)
docker run -p 8080:8080 \
  -e NAVER_API_BASE_URL=http://<proxy-host>:<port>/naver \
  -e NAVER_API_KEY=aaaaaa \
  -e NAVER_CLIENT_ID=xxxxxxxx \
  -e NAVER_CLIENT_SECRET=yyyyyyyy \
  -e NAVER_PROFILE=prod \
  <registry>/<repo>/naver-mcp:sse
```

```yaml
# K8s ConfigMap/Secret 예시 (발췌)
apiVersion: v1
kind: ConfigMap
metadata:
  name: naver-mcp-config
data:
  NAVER_API_BASE_URL: "http://<proxy-host>:<port>/naver"
  BRIDGE_PORT: "8080"
  NAVER_PROFILE: "prod"
---
apiVersion: v1
kind: Secret
metadata:
  name: naver-mcp-secret
type: Opaque
stringData:
  NAVER_API_KEY: "<your-api-key>"
  NAVER_CLIENT_ID: "<your-client-id>"
  NAVER_CLIENT_SECRET: "<your-client-secret>"
```

---

## 2) Docker 빌드/실행

```bash
# 빌드
docker build -t <registry>/<repo>/naver-mcp:sse .

---

## 4) 외부 Proxy(NGINX) 설정

```nginx
# Naver API (MCP 용)
location /naver/ {
    proxy_pass https://openapi.naver.com/;
    proxy_set_header Host openapi.naver.com;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_ssl_verify off;
    proxy_ssl_server_name on;
    proxy_connect_timeout 30s;
    proxy_send_timeout 30s;
    proxy_read_timeout 30s;

    # SSL 설정 추가
    proxy_ssl_protocols TLSv1.2 TLSv1.3;
    proxy_ssl_ciphers HIGH:!aNULL:!MD5;
}
```

---

## 원본 소스 및 라이선스 고지

이 저장소는 공개 저장소 `isnow890/naver-search-mcp`를 기반으로 일부 배포/설정(환경변수, Dockerfile 통합, README) 개선을 적용한 파생본입니다. 원본 저장소와 라이선스는 아래를 참고하세요.

- 원본 저장소: https://github.com/isnow890/naver-search-mcp
- 라이선스: MIT (원본과 동일)

