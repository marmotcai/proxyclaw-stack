# ProxyClaw Stack — 架构设计

## 1. 设计原则

1. **服务包独立** — `middleware/`、`services/mem0/`、`services/pi-sandbox/` 可单独部署
2. **统一编排** — 根目录 `start.sh` 负责启动、健康检查、日志，不嵌入业务逻辑
3. **配置集中** — 根目录 `.env` 为默认配置源（`--env-file` 注入各 compose）
4. **按需组网** — 仅 Mem0 等消费者加入共享网络 `proxyclaw-stack-network`

## 2. 目录结构

```
proxyclaw-stack/
├── start.sh                 # 统一入口
├── .env.example             # 全局配置模板
├── compose/
│   ├── fragments/           # 共享服务定义（PG/Redis/ES/Qdrant/Neo4j/Ollama/Mem0）
│   └── overrides/           # 部署场景覆盖（stack-middleware、stack-mem0、profile-agent-memory）
├── docs/                    # 文档（操作手册、架构）
├── middleware/              # 基础中间件包（独立）
│   ├── docker-compose.yml   # include fragments + stack-middleware override
│   └── README.md
└── services/
    ├── mem0/                # Mem0 服务包（依赖 middleware）
    │   ├── docker-compose.yml
    │   ├── Dockerfile
    │   └── README.md
    └── pi-sandbox/          # Pi Agent 网关（独立）
        ├── docker-compose.yml
        ├── Dockerfile
        ├── go-client/
        ├── pi-config/
        ├── docker/          # 开发双容器
        ├── scripts/
        └── README.md
```

## 3. 服务依赖关系

```
middleware/          services/mem0/          services/pi-sandbox/
(PG, Redis, ...)   (Mem0 Server)           (pi-server HTTP)
      │                    │                        │
      │    proxyclaw-stack-network (仅 mem0 加入)   │
      └────────────────────┘                        │
                                                     无 stack 内依赖
```

| 服务包 | 可独立启动 | 运行时依赖 |
|--------|-----------|-----------|
| middleware | ✅ | 无 |
| pi-sandbox | ✅ | LLM API Key |
| mem0 | ⚠️ 需中间件 | PG、Qdrant、Neo4j、Ollama |

## 4. 部署模式

```bash
./start.sh start base          # 仅 middleware
./start.sh start pi-sandbox    # 仅 Pi（无需 base）
./start.sh start mem0          # Mem0 + 自动拉起所需 middleware
./start.sh start all           # 全部
```

## 5. 网络

| 网络 | 创建者 | 使用者 |
|------|--------|--------|
| `proxyclaw-stack-network` | `start base` 或 `start.sh` 按需创建 | middleware、mem0 |
| `pi-network` | `services/pi-sandbox/docker/` 开发 compose | 开发双容器 |
| pi-sandbox 生产 compose 默认 bridge | Docker 自动 | 单容器生产 |

## 6. 数据卷

| Volume | 服务 |
|--------|------|
| `proxyclaw-stack_postgresql_data` 等 | middleware |
| `mem0_history_data` | mem0 |
| `pi-sandbox-sessions` / `pi-sandbox-workspace` | pi-sandbox |