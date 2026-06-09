# ProxyClaw Stack 文档

ProxyClaw Stack 是 **与 ProxyClaw 主项目配套的可选服务集合**，每个服务包可独立部署，由根目录 `start.sh` 统一编排。

## 文档索引

| 文档 | 说明 |
|------|------|
| [getting-started.md](getting-started.md) | 首次安装与启动 |
| [middleware-guide.md](middleware-guide.md) | PostgreSQL、Redis、Qdrant、Ollama 等中间件 |
| [mem0-guide.md](mem0-guide.md) | Mem0 记忆服务 |
| [pi-sandbox-guide.md](pi-sandbox-guide.md) | Pi Agent HTTP 网关 |
| [ARCHITECTURE.md](ARCHITECTURE.md) | 架构与目录结构 |
| [AGENTS.md](AGENTS.md) | AI 编码智能体入口 |
| [CONVENTIONS.md](CONVENTIONS.md) | 编码规范 |

## 服务包一览

```bash
./start.sh list    # 打印所有服务包及启动命令
```

| 包 | 路径 | 端口 | 依赖 |
|----|------|------|------|
| middleware | `middleware/` | 见各组件 | 无 |
| mem0 | `services/mem0/` | 20061 | middleware（PG/Qdrant/Neo4j/Ollama） |
| pi-sandbox | `services/pi-sandbox/` | 20062 | 无（仅需 LLM API Key） |

## 常用命令

```bash
./start.sh w              # 交互式向导
./start.sh start <服务>   # 启动
./start.sh stop <服务>    # 停止
./start.sh status         # 状态
./start.sh health         # 健康检查
./start.sh logs <服务>    # 日志
```