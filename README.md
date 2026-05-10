# ProxyClaw Stack

**ProxyClaw Stack** 是 ProxyClaw 的中间件与服务组件仓库，提供独立的 Docker 容器编排和统一的环境变量管理。

## 项目结构

```
proxyclaw-stack/
├── start.sh                    # 统一启动脚本
├── .env.example                # 环境变量模板
├── middleware/                 # 通用中间件
│   ├── docker-compose.yml      # Docker 编排
│   └── configs/                # 中间件配置
├── services/                   # 第三方服务
│   ├── mem0/                   # Mem0 记忆服务
│   │   ├── docker-compose.yml
│   │   └── entrypoint.sh
│   └── pi-sandbox/             # Pi Sandbox（单容器：pi + pi-server）
│       ├── docker-compose.yml
│       └── Dockerfile
├── pi-sandbox/                 # Pi 沙盒源码与独立脚本（可选本地开发）
└── plugins/                    # 客户端插件（待迁移）
```

## 快速开始

```bash
cd proxyclaw-stack

# 1. 配置环境变量
cp .env.example .env
vim .env

# 2. 启动基础中间件
./start.sh start base

# 3. 启动 Mem0（含依赖）
./start.sh start mem0

# （可选）启动 Pi Sandbox HTTP 网关
# ./start.sh start pi-sandbox

# 4. 查看状态
./start.sh status
```

## 可用服务

| 服务 | 说明 | 依赖 |
|------|------|------|
| `postgres` | PostgreSQL + pgvector | 无 |
| `redis` | Redis 缓存 | 无 |
| `elasticsearch` | 向量+KV存储 | 无 |
| `qdrant` | 向量数据库 | 无 |
| `neo4j` | 图数据库 | 无 |
| `ollama` | 本地模型服务 | 无 |
| `mem0` | 记忆服务 | postgresql, qdrant, neo4j |
| `pi-sandbox` | Pi Agent HTTP 网关（`/api/*`） | 无（需 LLM API Key） |

## 启动组合

```bash
./start.sh start base        # 所有基础中间件
./start.sh start mem0        # Mem0 + 依赖
./start.sh start pi-sandbox  # Pi Sandbox（首次会构建镜像）
./start.sh start all         # 基础 + Mem0 + Pi Sandbox
```

## 文档

- [AGENTS.md](AGENTS.md) - AI 智能体入口
- [ARCHITECTURE.md](ARCHITECTURE.md) - 架构设计
- [CONVENTIONS.md](CONVENTIONS.md) - 编码规范
- [docs/](docs/) - 详细文档