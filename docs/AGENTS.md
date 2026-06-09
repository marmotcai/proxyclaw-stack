# ProxyClaw Stack — Agent 入口

## 1. 项目是什么

**ProxyClaw Stack** 是与 ProxyClaw 主项目配套的**可选服务集合**（中间件、Mem0、Pi Sandbox）。各服务包**相互独立**，由根目录 `start.sh` 统一编排。

## 2. 服务端口（宿主机，真源见 `.env.example`）

| 服务 | 宿主机端口 | 容器 |
|------|-----------|------|
| PostgreSQL | 5432 | proxyclaw-postgresql |
| Redis | **26379** | proxyclaw-redis |
| Elasticsearch | **29200** | proxyclaw-elasticsearch |
| Qdrant | 6333 | proxyclaw-qdrant |
| Neo4j | 7474 / 7687 | proxyclaw-neo4j |
| Ollama | **21434** | proxyclaw-ollama |
| Mem0 | 20061 | proxyclaw-mem0 |
| Pi Sandbox | 20062 | proxyclaw-pi-sandbox |

## 3. 文档索引

| 任务 | 文档 |
|------|------|
| 首次启动 | [getting-started.md](getting-started.md) |
| Pi Sandbox | [pi-sandbox-guide.md](pi-sandbox-guide.md) |
| Mem0 | [mem0-guide.md](mem0-guide.md) |
| 中间件 | [middleware-guide.md](middleware-guide.md) |
| 架构 | [ARCHITECTURE.md](ARCHITECTURE.md) |

## 4. 常用命令

```bash
./start.sh list              # 服务包一览
./start.sh w                 # 交互向导
./start.sh start pi-sandbox  # 独立启动 Pi
./start.sh start mem0        # Mem0（自动拉 middleware）
./start.sh status
./start.sh health
```

## 5. 约束

- ❌ 禁止硬编码密钥
- ❌ 禁止提交 `.env`
- ✅ 改 `models.json` 后 `./start.sh restart pi-sandbox`