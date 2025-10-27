# Naver MCP Server – SSE 방식 Docker 이미지 빌드 가이드

외부 프록시 서버 → Naver API(역방향 프록시) 가정 하에, SSE 방식으로 MCP 서버를 빌드/배포하는 방법입니다.

---

## 1) Naver API 엔드포인트 수정

`/src/clients/naver-api-core.client.ts`

```ts
// AS-IS
export abstract class NaverApiCoreClient {
  protected searchBaseUrl = "https://openapi.naver.com/naver/v1/search";
  protected datalabBaseUrl = "https://openapi.naver.com/naver/v1/datalab";

// TO-BE
export abstract class NaverApiCoreClient {
  protected searchBaseUrl = "http://192.168.0.116:8091/naver/v1/search";
  protected datalabBaseUrl = "http://192.168.0.116:8091/naver/v1/datalab";
```
---

## 2) Docker 이미지 빌드

### Base image 빌드
```bash
docker build -t {이미지명} .
# EX) docker build -t 192.168.0.116/dmp-poc/mcp-server:v1.2 .
```

> **중요:** `Dockerfile.sse`의 base 이미지를 위에서 빌드한 **Base image**로 변경하세요.  
> 예) `Dockerfile.sse` 상단 `FROM 192.168.0.116/dmp-poc/mcp-server:v1.2`

### SSE image 빌드
```bash
docker build -f Dockerfile.sse -t {이미지명} .
# EX) docker build -f Dockerfile.sse -t 192.168.0.116/dmp-poc/mcp-server:sse-proxy-1027_1 .
```

이미지 푸시 후 K8s에 배포합니다.

---

## 3) 외부 Proxy(NGINX) 설정

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

