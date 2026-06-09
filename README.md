# ProxyClaw Stack

与 [ProxyClaw](https://github.com/marmotcai/proxyclaw) 配套的**可选服务集合**：中间件、Mem0 记忆、Pi Agent 网关。各服务包**相互独立**，由 `start.sh` 统一编排。

## 目录结构

```
proxyclaw-stack/
├── start.sh                    # 统一启动脚本
├── .env.example                # 全局环境变量
├── docs/                       # 文档与操作手册
│   ├── README.md               # 文档索引
│   ├── getting-started.md
│   ├── pi-sandbox-guide.md
│   ├── mem0-guide.md
│   └── middleware-guide.md
├── middleware/                   # 基础中间件（PG、Redis、Qdrant…）
└── services/
    ├── mem0/                   # Mem0 记忆服务
    └── pi-sandbox/             # Pi Agent HTTP 网关
```

## 快速开始

```bash
cd proxyclaw-stack
cp .env.example .env
./start.sh w                    # 交互式向导（推荐首次使用）

# 或按需启动
./start.sh start pi-sandbox     # Pi 网关（独立，端口 20062）
./start.sh start mem0           # Mem0（自动拉 middleware）
./start.sh start base           # 仅中间件
./start.sh start all            # 全部

./start.sh status
./start.sh list                 # 服务包说明
```

## 服务包

| 包 | 路径 | 端口 | 依赖 |
|----|------|------|------|
| middleware | `middleware/` | 见文档 | 无 |
| mem0 | `services/mem0/` | 20061 | middleware |
| pi-sandbox | `services/pi-sandbox/` | 20062 | 无（需 API Key） |

## 文档

| 文档 | 说明 |
|------|------|
| [docs/README.md](docs/README.md) | 文档索引 |
| [docs/getting-started.md](docs/getting-started.md) | 安装与首次启动 |
| [docs/pi-sandbox-guide.md](docs/pi-sandbox-guide.md) | **Pi 操作手册** |
| [docs/mem0-guide.md](docs/mem0-guide.md) | Mem0 操作手册 |
| [docs/middleware-guide.md](docs/middleware-guide.md) | 中间件说明 |
| [docs/AGENTS.md](docs/AGENTS.md) | AI Agent 入口 |

## 常用命令

```bash
./start.sh start <服务>    # 启动（支持简写 pg/rd/m0/pi）
./start.sh stop <服务>     # 停止
./start.sh restart <服务>  # 重启
./start.sh logs <服务>     # 日志
./start.sh health          # 健康检查
./start.sh clean <服务>    # 清理容器与数据卷
```