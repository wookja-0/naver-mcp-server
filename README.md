# Naver Search MCP Server – SSE 배포 가이드 (단일 Dockerfile)

**Naver Search MCP Server**는 Naver 검색 및 DataLab Open API를 MCP(Server-Sent Events) 프로토콜로 중계하는 단일 컨테이너 서비스입니다.  
하나의 Dockerfile로 빌드 및 실행할 수 있으며, `NAVER_API_BASE_URL` 환경 변수만으로 Naver API 또는 프록시를 지정할 수 있습니다.  
앱은 SSE 통신을 위해 컨테이너 내부에서 `mcp-proxy`를 사용합니다.

이 서버는 LangChain 등 MCP 클라이언트가 Naver 검색 및 DataLab API와 실시간으로 통신할 수 있도록 설계되었습니다.

---

## 1) 환경변수

| 변수명 | 필수 여부 | 기본값 | 설명 |
|--------|------------|--------|------|
| `NAVER_API_BASE_URL` | 선택 | `https://openapi.naver.com` | Naver API 기본 URL 또는 프록시 주소 |
| `NAVER_API_KEY` | **필수** | - | Naver API 인증 키 |
| `NAVER_CLIENT_ID` | **필수** | - | Naver API Client ID |
| `NAVER_CLIENT_SECRET` | **필수** | - | Naver API Client Secret |
| `NAVER_PROFILE` | 선택 | - | 서비스 또는 배포 환경을 식별하는 고유 프로파일 ID |
| `BRIDGE_PORT` | 선택 | `8080` | 서버 포트 |
| `NODE_ENV` | 선택 | `production` | Node 환경 변수 |

앱 내부에서는 `NAVER_API_BASE_URL` 뒤에 `/v1/search`, `/v1/datalab` 경로가 자동으로 붙습니다.  
후행 `/`는 자동 제거됩니다.

---

## 2) 소스코드 clone

```bash
git clone https://github.com/wookja-0/naver-mcp-server.git
```

---

## 3) Docker 빌드/실행

```bash
# 빌드
docker build -t <registry>/<repo>/naver-mcp:sse .
```

### 환경변수 설정 예시 (프록시 미사용)

```bash
# NAVER_API_BASE_URL 생략 가능 (기본값: https://openapi.naver.com)

docker run -p 8080:8080   -e NAVER_API_KEY=aaaaaa   -e NAVER_CLIENT_ID=xxxxxxxx   -e NAVER_CLIENT_SECRET=yyyyyyyy   <registry>/<repo>/naver-mcp:sse
```

### 환경변수 설정 예시 (프록시 사용)

```bash
docker run -p 8080:8080   -e NAVER_API_BASE_URL=http://<proxy-host>:<port>/naver   -e NAVER_API_KEY=aaaaaa   -e NAVER_CLIENT_ID=xxxxxxxx   -e NAVER_CLIENT_SECRET=yyyyyyyy  <registry>/<repo>/naver-mcp:sse
```

#### 외부 Proxy (NGINX) 설정

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

## 4) K8s 배포 시

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: naver-mcp-config
data:
  NAVER_API_BASE_URL: "http://<proxy-host>:<port>/naver"  # 프록시 서버 사용 시 추가, 미사용 시 제외
  BRIDGE_PORT: "8080"
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
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: naver-mcp-server
  labels: { app: naver-mcp-server }
spec:
  replicas: 1
  selector:
    matchLabels: { app: naver-mcp-server }
  template:
    metadata:
      labels: { app: naver-mcp-server }
    spec:
      containers:
        - name: naver-mcp-server
          image: <registry>/<repo>/naver-mcp:sse
          imagePullPolicy: IfNotPresent
          envFrom:
            - secretRef:
                name: naver-mcp-secret
            - configMapRef:
                name: naver-mcp-config
          env:
            - name: LOG_DIR
              value: "/var/log/naver-mcp"
          ports:
            - name: http
              containerPort: 8080
          volumeMounts:
            - name: logs
              mountPath: /var/log/naver-mcp
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
      volumes:
        - name: logs
          persistentVolumeClaim:
            claimName: naver-mcp-logs
```

---

## 5) 백엔드(클라이언트) 연결 예시

```python
from langchain_mcp_adapters.client import MultiServerMCPClient

mcp_client = MultiServerMCPClient(
    {
        "naver-search-mcp": {
            "transport": "sse",
            "url": "http://<mcp-server-host>:8080/sse"  # 예) http://naver-mcp-server.svc.cluster.local:8080/sse
        }
    }
)
```

> NodePort로 노출한 경우: 워커 노드 IP와 NodePort를 사용

---

## 원본 소스 및 라이선스

- 원본 저장소: [isnow890/naver-search-mcp](https://github.com/isnow890/naver-search-mcp)
- 라이선스: MIT

---

> Smithery 전용 경로(`/@org/server/mcp?...`)는 사용하지 않습니다.  
> 서버 컨테이너에는 `NAVER_CLIENT_ID/SECRET`(K8s Secret)이 주입되어 네이버 API를 호출합니다.
