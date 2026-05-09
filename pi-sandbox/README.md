# Pi Sandbox - Go 客户端容器方案

一个基于 Docker 容器的 Pi Agent 沙盒方案，使用 Go 语言实现客户端，提供安全隔离和资源控制。

## 架构概览

```
┌─────────────────────────────────────────────────────────┐
│                    Go 宿主进程                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │
│  │ 安全控制层   │  │ 资源管理     │  │ 业务逻辑层      │ │
│  │ - 文件系统   │  │ - CPU/内存   │  │ - 权限策略      │ │
│  │ - 网络访问   │  │ - 超时控制   │  │ - 审计日志      │ │
│  │ - 系统调用   │  │ - 进程隔离   │  │ - 工作流编排    │ │
│  └──────┬──────┘  └──────┬──────┘  └────────┬────────┘ │
│         │                │                   │          │
│         └────────────────┼───────────────────┘          │
│                          │                              │
│                    ┌─────▼─────┐                        │
│                    │ RPC 客户端 │                        │
│                    │ (stdin/   │                        │
│                    │  stdout)  │                        │
│                    └─────┬─────┘                        │
└──────────────────────────┼──────────────────────────────┘
                           │ JSONL 协议
┌──────────────────────────┼──────────────────────────────┐
│                    ┌─────▼─────┐                        │
│                    │ Pi 容器    │                        │
│                    │ (沙盒内)   │                        │
│                    └───────────┘                        │
└─────────────────────────────────────────────────────────┘
```

## 功能特性

### 1. 容器编排
- ✅ Docker Compose 一键启动
- ✅ 环境变量通过 `.env` 文件注入
- ✅ 资源限制（CPU、内存）
- ✅ 健康检查
- ✅ 日志管理

### 2. Go 客户端
- ✅ RPC 协议客户端
- ✅ 流式输出支持
- ✅ 多会话管理
- ✅ 安全策略控制
- ✅ 审计日志
- ✅ HTTP API 服务器
- ✅ 命令行工具

### 3. 安全控制
- ✅ 文件路径白名单/黑名单
- ✅ 命令黑名单
- ✅ 网络访问控制
- ✅ 工具调用验证

## 快速开始

### 1. 配置环境

```bash
# 复制配置文件
cp .env.example .env

# 编辑配置，填入 API 密钥
vim .env
```

### 2. 启动服务

```bash
# 给脚本执行权限
chmod +x scripts/*.sh

# 构建并启动
./scripts/manage.sh build
./scripts/manage.sh start
```

### 3. 测试连接

```bash
# 查看服务状态
./scripts/manage.sh status

# 测试 RPC 连接
./scripts/manage.sh test

# 进入 Pi 容器
./scripts/manage.sh shell
```

### 4. 使用 Go 客户端

```bash
# 编译客户端
cd go-client
go build -o pi-cli ./cmd/cli
go build -o pi-server ./cmd/server

# 使用命令行客户端
./pi-cli --dir /path/to/workspace

# 启动 HTTP 服务器
./pi-server
```

## 目录结构

```
pi-sandbox/
├── .env.example              # 环境变量示例
├── .env                      # 环境变量配置（需创建）
├── README.md                 # 本文件
├── docker/
│   ├── Dockerfile.pi         # Pi 容器镜像
│   ├── docker-compose.yml    # 容器编排配置
│   ├── workspace/            # 工作目录
│   ├── extensions/           # 自定义扩展
│   └── skills/               # 自定义技能
├── go-client/
│   ├── go.mod                # Go 模块配置
│   ├── cmd/
│   │   ├── cli/              # 命令行客户端
│   │   └── server/           # HTTP 服务器
│   └── pkg/
│       ├── client/           # RPC 客户端库
│       └── security/         # 安全控制库
├── examples/
│   └── test_examples.go      # 测试示例
└── scripts/
    ├── manage.sh             # 管理脚本
    └── test.sh               # 测试脚本
```

## 配置说明

### 环境变量 (.env)

```bash
# LLM Provider API Keys（至少配置一个）
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
GOOGLE_API_KEY=...
DEEPSEEK_API_KEY=...

# 默认模型配置
PI_DEFAULT_PROVIDER=anthropic
PI_DEFAULT_MODEL=claude-sonnet-4-20250514
PI_THINKING_LEVEL=medium

# 安全设置
PI_ALLOWED_PATHS=/workspace,/tmp
PI_BLOCKED_PATHS=/etc,/root,/home
PI_ALLOW_NETWORK=true

# 资源限制
PI_MAX_MEMORY=512m
PI_MAX_CPU=1.0
PI_TIMEOUT_SECONDS=300
```

## 使用示例

### 1. 基本对话

```go
package main

import (
    "context"
    "fmt"
    "github.com/pi-sandbox/go-client/pkg/client"
)

func main() {
    // 创建客户端
    piClient, err := client.NewPiClient(".", "--no-session")
    if err != nil {
        panic(err)
    }
    defer piClient.Close()
    
    // 连接
    ctx := context.Background()
    if err := piClient.Connect(ctx); err != nil {
        panic(err)
    }
    
    // 设置事件处理器
    piClient.SetEventHandler(func(event client.Event) {
        if event.Type == client.EventMessageUpdate {
            // 处理流式输出
            fmt.Print("█")
        }
    })
    
    // 发送提示
    piClient.Prompt("Hello, what can you help me with?")
    
    // 等待响应...
}
```

### 2. 多会话管理

```go
// 创建管理器
config := client.DefaultManagerConfig()
manager := client.NewAgentManager(".", config)
defer manager.CloseAll()

// 创建多个会话
session1, _ := manager.CreateSession("session-1")
session2, _ := manager.CreateSession("session-2")

// 使用不同会话
session1.Client.Prompt("Help me with Go")
session2.Client.Prompt("Help me with Python")
```

### 3. 工作流执行

```go
// 定义工作流
workflow := &client.Workflow{
    Name: "Code Review",
    Steps: []client.WorkflowStep{
        {
            Name:   "List Files",
            Prompt: "List all .go files",
        },
        {
            Name:   "Analyze",
            Prompt: "Analyze code structure",
        },
    },
}

// 执行工作流
ctx := context.Background()
manager.ExecuteWorkflow(ctx, workflow, "my-session")
```

### 4. HTTP API

```bash
# 创建会话
curl -X POST http://localhost:8080/api/sessions \
  -H "Content-Type: application/json" \
  -d '{"id": "my-session"}'

# 发送提示
curl -X POST http://localhost:8080/api/prompt \
  -H "Content-Type: application/json" \
  -d '{"session_id": "my-session", "message": "Hello!"}'

# 查看状态
curl http://localhost:8080/api/status

# 删除会话
curl -X DELETE http://localhost:8080/api/sessions/my-session
```

## 安全策略

### 文件访问控制

```go
policy := &security.SecurityPolicy{
    AllowedPaths: []string{"/workspace", "/tmp"},
    BlockedPaths: []string{"/etc", "/root"},
    MaxFileSize:  10 * 1024 * 1024, // 10MB
}
```

### 命令黑名单

```go
policy.BlockedCommands = []string{
    "rm -rf /",
    "sudo",
    "chmod 777",
    "curl | sh",
}
```

### 工具调用验证

```go
validator := security.NewToolCallValidator(policy)

// 验证工具调用
err := validator.ValidateToolCall("bash", map[string]interface{}{
    "command": "ls -la",
})
```

## 管理命令

```bash
# 构建镜像
./scripts/manage.sh build

# 启动服务
./scripts/manage.sh start

# 停止服务
./scripts/manage.sh stop

# 重启服务
./scripts/manage.sh restart

# 查看日志
./scripts/manage.sh logs

# 查看状态
./scripts/manage.sh status

# 进入容器
./scripts/manage.sh shell

# 测试连接
./scripts/manage.sh test

# 清理数据
./scripts/manage.sh clean
```

## 测试

```bash
# 运行所有测试
./scripts/test.sh

# 运行 Go 测试
cd go-client
go test ./...

# 运行示例
cd examples
go run test_examples.go
```

## 常见问题

### Q: 如何添加自定义扩展？

将扩展文件放在 `docker/extensions/` 目录下，Pi 会自动加载。

### Q: 如何修改资源限制？

编辑 `.env` 文件中的 `PI_MAX_MEMORY` 和 `PI_MAX_CPU` 变量。

### Q: 如何查看 Pi 日志？

```bash
./scripts/manage.sh logs pi-agent
```

### Q: 如何持久化会话数据？

会话数据自动持久化到 Docker volume `pi-sessions`。

## 许可证

MIT License
