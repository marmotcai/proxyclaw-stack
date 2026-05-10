# ProxyClaw Stack — Agent 入口

## 1. 项目职责

ProxyClaw Stack 专注于 **中间件容器编排与环境变量管理**，不包含业务逻辑。

## 2. 服务端口（真源）

| 服务 | 端口 | Docker 服务名 |
|------|------|--------------|
| PostgreSQL | 5432 | postgresql |
| Redis | 6379 | redis |
| Elasticsearch | 9200 | elasticsearch |
| Qdrant | 6333 | qdrant |
| Neo4j HTTP | 7474 | neo4j |
| Neo4j Bolt | 7687 | neo4j |
| Ollama | 11434 | ollama |
| Mem0 | 20061 | mem0-server |
| Pi Sandbox | 20062 | proxyclaw-pi-sandbox（HTTP 网关） |

## 3. 依赖关系

```
mem0-server → postgresql
             → qdrant
             → neo4j
```

## 4. 常用命令

```bash
./start.sh start base          # 启动所有基础中间件
./start.sh start mem0          # 启动 Mem0（含依赖）
./start.sh start pi-sandbox    # 启动 Pi Sandbox（Pi Agent HTTP 网关）
./start.sh stop mem0           # 停止 Mem0
./start.sh stop pi-sandbox     # 停止 Pi Sandbox
./start.sh status              # 查看状态
./start.sh health             # 健康检查
./start.sh logs <服务>         # 查看日志
```

## 5. 环境变量

环境变量统一配置在 `.env` 文件，关键变量：

| 变量 | 说明 |
|------|------|
| `POSTGRES_PASSWORD` | PostgreSQL 密码 |
| `MEM0_ADMIN_API_KEY` | Mem0 认证密钥 |
| `MEM0_OPENAI_API_KEY` | Mem0 LLM API Key |
| `NEO4J_PASSWORD` | Neo4j 密码 |

## 6. 约束

- ❌ 禁止在配置中硬编码密钥
- ❌ 禁止提交 `.env` 文件（只提交 `.env.example`）
- ✅ 使用 Docker profiles 管理服务启动组合