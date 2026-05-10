# 构建上下文为仓库根目录（见 services/pi-sandbox/docker-compose.yml）
FROM docker.m.daocloud.io/library/golang:1.23-alpine AS gobuild
WORKDIR /src
COPY pi-sandbox/go-client/go.mod /src/go.mod
COPY pi-sandbox/go-client/ /src/
RUN go mod download && CGO_ENABLED=0 GOOS=linux go build -o /pi-server ./cmd/server

FROM docker.m.daocloud.io/library/node:20-alpine
RUN apk add --no-cache ca-certificates curl git
RUN npm install -g @mariozechner/pi-coding-agent
WORKDIR /workspace
RUN mkdir -p /data/sessions /workspace
COPY --from=gobuild /pi-server /usr/local/bin/pi-server
ENV PORT=:8080
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
    CMD curl -fsS http://127.0.0.1:8080/api/health >/dev/null || exit 1
ENTRYPOINT ["/usr/local/bin/pi-server"]
