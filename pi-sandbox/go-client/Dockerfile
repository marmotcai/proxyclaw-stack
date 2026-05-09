FROM golang:1.21-alpine AS builder

WORKDIR /app

# 使用国内 Go 代理
ENV GOPROXY=https://goproxy.cn,direct
ENV GO111MODULE=on

# 复制依赖文件
COPY go.mod go.sum ./
RUN go mod download

# 复制源代码
COPY . .

# 编译
RUN CGO_ENABLED=0 GOOS=linux go build -o /pi-cli ./cmd/cli
RUN CGO_ENABLED=0 GOOS=linux go build -o /pi-server ./cmd/server

# 运行时镜像
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /app

# 复制编译产物
COPY --from=builder /pi-cli /usr/local/bin/pi-cli
COPY --from=builder /pi-server /usr/local/bin/pi-server

# 默认启动服务器
EXPOSE 8080

ENTRYPOINT ["pi-server"]
