# DeerFlow 2.0 Windows 10/11 本地部署指南

> 基于 DeerFlow 2.0 原版修改，支持无 nginx 的 Windows 原生直连模式。
>
> 最后更新：2026-03-20

---

## 目录

1. [项目简介](#1-项目简介)
2. [系统要求](#2-系统要求)
3. [架构概览](#3-架构概览)
4. [安装步骤](#4-安装步骤)
5. [配置说明](#5-配置说明)
6. [启动与停止](#6-启动与停止)
7. [访问应用](#7-访问应用)
8. [常见问题排查](#8-常见问题排查)
9. [与原版的区别](#9-与原版的区别)

---

## 1. 项目简介

DeerFlow 是字节跳动开源的 AI Super Agent 系统，基于 LangGraph 和 LangChain 构建。它集成了子 Agent 调度、长期记忆、沙箱执行、MCP 工具扩展和技能系统，能够完成深度研究、报告生成、PPT 制作、代码开发等复杂任务。

本指南针对 Windows 10/11 环境，修改了原版依赖 nginx 的架构，实现**无需安装 nginx 即可运行**的直连模式。

### 核心特性

- **多模型支持**：兼容 OpenAI、Anthropic、Google Gemini、DeepSeek、Ollama 本地模型等
- **内置工具**：Web 搜索、Web 抓取、图片搜索、文件操作、Bash 执行
- **MCP 扩展**：通过 `extensions_config.json` 集成外部 MCP 工具（filesystem、GitHub、数据库等）
- **技能系统**：内置研究、报告生成、PPT 创建等技能，支持自定义扩展
- **长期记忆**：跨会话持久化用户偏好和上下文
- **子 Agent 调度**：自动分解复杂任务，并行执行后汇总结果
- **IM 渠道**：支持飞书、Slack、Telegram 接入

---

## 2. 系统要求

### 必需软件

| 软件 | 版本要求 | 下载地址 |
|------|----------|----------|
| **Node.js** | 22+ | https://nodejs.org/ |
| **pnpm** | 最新版 | `npm install -g pnpm` |
| **uv** | 最新版 | https://docs.astral.sh/uv/getting-started/installation/ |
| **Python** | 3.12+ | uv 会自动管理，无需单独安装 |

### 可选软件

| 软件 | 说明 | 下载地址 |
|------|------|----------|
| **Ollama** | 本地大语言模型运行时 | https://ollama.com/ |
| **Docker Desktop** | 容器化沙箱执行（可选） | https://www.docker.com/products/docker-desktop/ |
| **Git** | 版本控制（推荐） | https://git-scm.com/ |

### 硬件建议

- **内存**：8GB+（推荐 16GB+）
- **磁盘**：2GB+ 可用空间
- **GPU**：如需本地运行大模型，建议有 NVIDIA GPU

---

## 3. 架构概览

### 原版架构（需要 nginx）

```
浏览器 → nginx (2026) → Frontend (3000)
                       → Gateway (8001)
                       → LangGraph (2024)
```

### 修改后架构（Windows 直连模式）

```
浏览器 → Frontend (3000) → Gateway (8001)  [直连，CORS 已配置]
                          → LangGraph (2024) [直连]
```

### 端口说明

| 端口 | 服务 | 说明 |
|------|------|------|
| **3000** | Next.js 前端 | 用户界面，直接浏览器访问 |
| **2024** | LangGraph Server | Agent 运行时，处理对话和工具调用 |
| **8001** | Gateway API (FastAPI) | REST API：模型管理、MCP 配置、记忆、技能、文件上传 |
| **2026** | Nginx（可选） | 统一反向代理入口，Windows 下无需安装 |
| **11434** | Ollama（可选） | 本地大模型服务 |

---

## 4. 安装步骤

### 4.1 克隆项目

```powershell
git clone https://github.com/bytedance/deer-flow.git
cd deer-flow
```

### 4.2 检查依赖

```powershell
python scripts\check.py
```

确保 Node.js 22+、pnpm、uv 已安装。在 Windows 上 nginx 为可选组件，缺失不会报错。

### 4.3 安装项目依赖

```powershell
.\scripts\install.ps1
```

或手动执行：

```powershell
# 安装后端依赖
cd backend
uv sync

# 安装前端依赖
cd ..\frontend
pnpm install
```

### 4.4 生成配置文件

```powershell
python scripts\configure.py
```

这会从示例模板生成以下文件：
- `config.yaml` — 主配置（模型、工具、记忆等）
- `.env` — 环境变量（API Key）
- `frontend/.env` — 前端环境变量

> **注意**：如果配置文件已存在，`configure.py` 不会覆盖。你需要手动应用下一节的修改。

### 4.5 创建 MCP 扩展配置（可选）

```powershell
copy extensions_config.example.json extensions_config.json
```

编辑 `extensions_config.json`，根据需要启用 MCP 服务器。

---

## 5. 配置说明

### 5.1 前端直连模式（关键修改）

编辑 `frontend/.env`，取消注释并设置后端直连地址：

```env
# 直连模式（无需 nginx）
NEXT_PUBLIC_BACKEND_BASE_URL="http://localhost:8001"
NEXT_PUBLIC_LANGGRAPH_BASE_URL="http://localhost:2024"
```

> **重要**：`NEXT_PUBLIC_*` 环境变量修改后**必须重启 Next.js** 才能生效。

### 5.2 Gateway CORS 配置（关键修改）

编辑 `backend/app/gateway/app.py`，在 `create_app()` 函数中添加 CORS 中间件：

```python
from fastapi.middleware.cors import CORSMiddleware

# 在 app = FastAPI(...) 之后、app.include_router(...) 之前添加：
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

原版没有此中间件（注释写着 "CORS is handled by nginx"），在无 nginx 的 Windows 环境下会导致浏览器跨域请求失败。

### 5.3 模型配置

编辑 `config.yaml` 的 `models` 部分，配置至少一个可用模型：

#### 使用 Ollama 本地模型（无需 API Key）

```yaml
models:
  - name: qwen3.5-27b
    display_name: Qwen 3.5 27B (Ollama)
    use: langchain_openai:ChatOpenAI
    model: qwen3.5:27b
    base_url: http://localhost:11434/v1
    api_key: ollama
    max_tokens: 8192
    temperature: 0.7
```

#### 使用 OpenAI / DeepSeek / 其他云模型

```yaml
models:
  - name: deepseek-v3
    display_name: DeepSeek V3
    use: langchain_openai:ChatOpenAI
    model: deepseek-chat
    api_key: $DEEPSEEK_API_KEY
    base_url: https://api.deepseek.com/v1
    max_tokens: 8192
    temperature: 0.7
```

然后在 `.env` 中设置对应的 API Key：

```env
DEEPSEEK_API_KEY=sk-xxxxxxxxxxxxx
```

### 5.4 搜索工具配置

默认的 `web_search` 使用 Tavily，需要 API Key：

```env
TAVILY_API_KEY=tvly-xxxxxxxxxxxxx
```

如需切换到其他搜索引擎，编辑 `config.yaml` 中的 `tools` 部分。

**`image_search`（DuckDuckGo）无需任何 API Key**，可直接使用。

### 5.5 MCP 扩展配置

编辑 `extensions_config.json`：

```json
{
  "mcpServers": {
    "filesystem": {
      "enabled": true,
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "D:/your/path"],
      "env": {},
      "description": "Provides filesystem access within allowed directories"
    },
    "github": {
      "enabled": false,
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {"GITHUB_TOKEN": "$GITHUB_TOKEN"},
      "description": "GitHub MCP server for repository operations"
    }
  },
  "skills": {}
}
```

### 5.6 完整 `.env` 示例

```env
# 搜索工具
TAVILY_API_KEY=tvly-xxxxxxxxxxxxx
JINA_API_KEY=jina_xxxxxxxxxxxxx

# 模型 API Keys（根据 config.yaml 中使用的模型配置）
DEEPSEEK_API_KEY=sk-xxxxxxxxxxxxx
OPENAI_API_KEY=sk-xxxxxxxxxxxxx

# MCP 工具（可选）
GITHUB_TOKEN=ghp_xxxxxxxxxxxxx

# IM 渠道（可选，全部注释掉不影响使用）
# FEISHU_APP_ID=cli_xxxx
# FEISHU_APP_SECRET=your_secret
# SLACK_BOT_TOKEN=xoxb-...
# SLACK_APP_TOKEN=xapp-...
# TELEGRAM_BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrSTUvwxYZ
```

---

## 6. 启动与停止

### 6.1 启动服务（开发模式）

```powershell
.\scripts\dev.ps1
```

启动脚本会按顺序执行：
1. 停止已有服务（释放端口 2024、8001、3000）
2. 自动升级配置（`config_upgrade.py`）
3. 启动 LangGraph Server（端口 2024），等待就绪
4. 启动 Gateway API（端口 8001），等待就绪
5. 启动 Next.js 前端（端口 3000），等待就绪

所有服务运行在后台 PowerShell Job 中，日志输出到 `logs/` 目录。

### 6.2 生产模式启动

```powershell
.\scripts\dev.ps1 -Prod
```

生产模式禁用热重载，前端会执行 `pnpm run preview`（先 build 再 start）。

### 6.3 停止服务

```powershell
.\scripts\stop.ps1
```

按端口和进程名清理所有服务。如果端口仍被占用：

```powershell
# 查找占用端口的进程
netstat -ano | findstr :8001

# 强制终止（需要管理员权限）
taskkill /F /PID <PID>
```

### 6.4 手动启动各服务（调试用）

```powershell
# 终端 1：LangGraph Server
cd backend
$env:DEER_FLOW_CONFIG_PATH = "D:\workAI\DeerFlow\deer-flow20\config.yaml"
uv run langgraph dev --no-browser --allow-blocking

# 终端 2：Gateway API
cd backend
$env:PYTHONPATH = "."
uv run uvicorn app.gateway.app:app --host 0.0.0.0 --port 8001

# 终端 3：Frontend
cd frontend
pnpm run dev
```

---

## 7. 访问应用

### 主要入口

| 入口 | 地址 | 说明 |
|------|------|------|
| **Web 界面** | http://localhost:3000 | 前端应用（推荐） |
| API 文档 | http://localhost:8001/docs | Gateway Swagger UI |
| ReDoc | http://localhost:8001/redoc | Gateway API 文档 |
| 健康检查 | http://localhost:8001/health | Gateway 健康状态 |

### 功能页面

- **对话**：http://localhost:3000/workspace/chats/new — 创建新对话
- **设置**：点击左下角设置图标 → 外观 / 通知 / 记忆 / 工具 / 技能 / 关于

---

## 8. 常见问题排查

### Q1: 启动后浏览器显示 404

**原因**：前端 `.env` 未配置直连模式。

**解决**：检查 `frontend/.env` 是否包含：
```env
NEXT_PUBLIC_BACKEND_BASE_URL="http://localhost:8001"
NEXT_PUBLIC_LANGGRAPH_BASE_URL="http://localhost:2024"
```
修改后需要**重启前端服务**。

### Q2: 设置页面（记忆/工具/技能）显示 "Failed to fetch"

**原因**：Gateway 未配置 CORS 中间件。

**解决**：检查 `backend/app/gateway/app.py` 是否包含 `CORSMiddleware` 配置（见 5.2 节），修改后**重启 Gateway**。

### Q3: 对话正常但网络搜索不可用

**原因**：搜索工具的 API Key 未配置。

**解决**：
1. 在 `.env` 中设置 `TAVILY_API_KEY`（获取方式：https://tavily.com 注册，免费套餐每月 1000 次）
2. 或在 `config.yaml` 中切换到 InfoQuest（`$INFOQUEST_API_KEY`）
3. `image_search`（DuckDuckGo）无需 Key，可直接使用

### Q4: 工具页面为空

**原因**：缺少 `extensions_config.json` 文件。

**解决**：
```powershell
copy extensions_config.example.json extensions_config.json
```
然后编辑该文件，至少启用一个 MCP 服务器（`"enabled": true`）。

### Q5: 端口被占用无法启动

**解决**：
```powershell
# 查看占用端口的进程
netstat -ano | findstr ":2024 :8001 :3000" | findstr "LISTENING"

# 强制终止（PID 替换为实际值）
taskkill /F /PID <PID>
```

### Q6: stop.ps1 提示端口仍被使用但进程不存在

**原因**：Windows 端口释放延迟。

**解决**：等待 5-10 秒后重试，或以管理员身份运行：
```powershell
Start-Process taskkill -ArgumentList '/F /PID <PID>' -Verb RunAs -Wait
```

### Q7: LangGraph 启动失败

**原因**：通常是配置文件错误。

**解决**：查看日志：
```powershell
Get-Content logs\langgraph.log -Tail 30
```

常见问题：
- `config.yaml` 中模型配置的 `api_key` 对应的环境变量未设置
- Python 依赖未安装（重新运行 `uv sync`）

### Q8: 前端构建错误（环境变量验证失败）

**解决**：跳过环境变量验证：
```powershell
$env:SKIP_ENV_VALIDATION = "1"
pnpm run dev
```

---

## 9. 与原版的区别

以下是本修改版相对于 DeerFlow 2.0 原版的所有变更：

### 修改 1：前端直连模式

**文件**：`frontend/.env`

| 项目 | 原版 | 修改版 |
|------|------|--------|
| `NEXT_PUBLIC_BACKEND_BASE_URL` | 注释掉（走 nginx） | `"http://localhost:8001"` |
| `NEXT_PUBLIC_LANGGRAPH_BASE_URL` | 注释掉（走 nginx） | `"http://localhost:2024"` |

**目的**：让前端直接连接 Gateway 和 LangGraph，绕过 nginx 反向代理。

### 修改 2：Gateway CORS 中间件

**文件**：`backend/app/gateway/app.py`

**新增导入**：
```python
from fastapi.middleware.cors import CORSMiddleware
```

**新增中间件**（在路由注册之前）：
```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

**目的**：原版注释写着 "CORS is handled by nginx"，Gateway 本身没有 CORS 处理。前端直连时，浏览器跨域请求被拒绝，导致设置页面 "Failed to fetch"。

### 修改 3：MCP 扩展配置

**文件**：`extensions_config.json`（新增）

从 `extensions_config.example.json` 创建，启用 filesystem MCP 服务器并配置实际路径。

### 未修改部分

以下文件和功能**未做任何修改**，保持原版不变：

- `config.yaml`（模型配置为当前环境定制，但结构未变）
- `scripts/dev.ps1` / `scripts/stop.ps1` / `scripts/install.ps1`
- `backend/app/gateway/routers/` 下所有路由
- `backend/packages/harness/` 下所有核心代码
- `frontend/src/` 下所有前端源码
- `docker/` 下所有 Docker 配置
- `skills/` 下所有技能文件
- `Makefile`、`langgraph.json` 等构建配置

### 恢复原版方式

如需恢复原版行为（通过 nginx 访问）：

1. 将 `frontend/.env` 中的两个 `NEXT_PUBLIC_*` 变量重新注释掉
2. 删除 `backend/app/gateway/app.py` 中的 CORS 中间件代码
3. 安装 nginx 并启动：`nginx -c docker/nginx/nginx.local.conf -p .`
4. 重启所有服务

---

## 附录

### A. 项目文件结构

```
deer-flow/
├── config.yaml                    # 主配置文件（模型、工具、记忆等）
├── extensions_config.json         # MCP 扩展配置（新增）
├── .env                           # 环境变量（API Keys）
├── frontend/
│   ├── .env                       # 前端环境变量（已修改）
│   ├── package.json
│   └── src/                       # 前端源码
├── backend/
│   ├── app/gateway/
│   │   ├── app.py                 # Gateway 入口（已修改，添加 CORS）
│   │   └── routers/               # API 路由
│   ├── langgraph.json             # LangGraph 配置
│   └── packages/harness/          # 核心 Agent 框架
├── scripts/
│   ├── dev.ps1                    # Windows 启动脚本
│   ├── stop.ps1                   # Windows 停止脚本
│   └── install.ps1                # Windows 安装脚本
├── docker/nginx/                  # Nginx 配置（Windows 下不需要）
└── skills/                        # Agent 技能
    ├── public/                    # 内置技能
    └── custom/                    # 自定义技能
```

### B. 常用命令速查

```powershell
# 启动
.\scripts\dev.ps1                  # 开发模式
.\scripts\dev.ps1 -Prod           # 生产模式

# 停止
.\scripts\stop.ps1                 # 停止所有服务

# 安装
.\scripts\install.ps1              # 安装依赖
python scripts\configure.py        # 生成配置文件

# 检查
python scripts\check.py            # 检查依赖

# 手动重启单个服务（Gateway 修改后需要）
# 先 stop，再 dev
```

### C. 日志位置

```
logs/
├── langgraph.log     # Agent 运行时日志
├── gateway.log       # API Gateway 日志
└── frontend.log      # Next.js 前端日志
```

### D. 相关链接

- **DeerFlow GitHub**：https://github.com/bytedance/deer-flow
- **DeerFlow 官网**：https://deerflow.tech
- **LangGraph 文档**：https://langchain-ai.github.io/langgraph/
- **MCP 协议**：https://modelcontextprotocol.io
- **Ollama**：https://ollama.com
