# 🦌 DeerFlow 2.0 — Windows 原生适配版

> 基于 [bytedance/deer-flow](https://github.com/bytedance/deer-flow) 的 Windows 10/11 原生适配。无需 Docker，无需 nginx，开箱即用。

[English](./README.md) | 中文

[![Python](https://img.shields.io/badge/Python-3.12%2B-3776AB?logo=python&logoColor=white)](./backend/pyproject.toml)
[![Node.js](https://img.shields.io/badge/Node.js-22%2B-339933?logo=node.js&logoColor=white)](./Makefile)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D6?logo=windows&logoColor=white)](./docs/WINDOWS_DEPLOY.md)

## 这是什么？

[DeerFlow](https://github.com/bytedance/deer-flow) 是字节跳动开源的 AI Super Agent 系统，基于 LangGraph 和 LangChain 构建。它能调度子 Agent、长期记忆、沙箱执行、技能和工具，完成深度研究、报告生成、PPT 制作等复杂任务。

**本项目**是 DeerFlow 2.0 的 Windows 原生适配版。原版项目依赖 Docker + nginx 环境（面向 Linux/macOS），Windows 用户上手门槛很高。本仓库通过少量针对性修改，去掉了这些依赖——不需要 Docker，不需要 nginx，不需要 WSL，直接在 Windows 上跑。

### 改了什么？

| # | 文件 | 修改内容 | 原因 |
|---|------|----------|------|
| 1 | `frontend/.env` | 取消注释 `NEXT_PUBLIC_BACKEND_BASE_URL` 和 `NEXT_PUBLIC_LANGGRAPH_BASE_URL` | 让前端直连后端，绕过 nginx |
| 2 | `backend/app/gateway/app.py` | 添加 `CORSMiddleware` | 原版 CORS 由 nginx 处理，直连模式需要在 FastAPI 中配置 |
| 3 | `extensions_config.json` | 从示例文件创建，启用 filesystem MCP | 缺少此文件时，设置页面的"工具"标签页为空 |
| 4 | `backend/.../config/paths.py` | Windows 下跳过 `chmod 0o777` | Windows 上 chmod 无效且可能引发异常 |
| 5 | `backend/.../sandbox/local/local_sandbox.py` | Windows 下检测 `cmd.exe` 作为 shell | 原版只查找 Unix shell |
| 6 | `backend/.../sandbox/tools.py` | 添加 Windows 系统路径前缀 | 让系统能识别 `C:\Windows\System32\` 等 Windows 路径 |
| 7 | `scripts/check.py` | 修复 Unicode 输出和 `shell=True` | GBK 控制台编码会导致 ✓ 等符号乱码 |
| 8 | `scripts/dev.ps1`、`stop.ps1`、`install.ps1` | 新增 PowerShell 启动/停止/安装脚本 | 原版只提供 Unix Shell 的 Makefile |

**核心 Agent 框架源码未做任何修改。** 所有改动都是平台适配层面的，涉及配置、Shell 检测和启动脚本。

## 快速开始

### 前置要求

| 软件 | 版本要求 | 安装地址 |
|------|----------|----------|
| Node.js | 22+ | https://nodejs.org/ |
| pnpm | 最新版 | `npm install -g pnpm` |
| uv | 最新版 | https://docs.astral.sh/uv/getting-started/installation/ |
| Python | 3.12+ | uv 会自动管理，无需单独安装 |

> Docker 和 nginx **不需要安装**。Ollama 为可选组件（用于运行本地大模型）。

### 1. 克隆 & 安装

```powershell
git clone https://github.com/hougithub2018/deer-flow-windows.git
cd deer-flow-windows

# 安装依赖
.\scripts\install.ps1
```

### 2. 配置

```powershell
# 从模板生成配置文件
python scripts\configure.py
```

然后编辑生成的文件：

**`config.yaml`** — 至少配置一个模型：
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

**`.env`** — 设置 API Key：
```env
DEEPSEEK_API_KEY=sk-xxxxxxxxxxxxx
TAVILY_API_KEY=tvly-xxxxxxxxxxxxx
```

### 3. 启用 MCP 扩展（可选）

```powershell
copy extensions_config.example.json extensions_config.json
```

编辑 `extensions_config.json`，根据需要启用 MCP 服务器（filesystem、GitHub 等）。

### 4. 启动

```powershell
.\scripts\dev.ps1
```

浏览器打开 **http://localhost:3000** 就可以了。

### 停止

```powershell
.\scripts\stop.ps1
```

## 架构

### 原版架构（需要 nginx）

```
浏览器 → nginx (:2026) → 前端 (:3000)
                       → Gateway (:8001)
                       → LangGraph (:2024)
```

### 修改后架构（直连模式）

```
浏览器 → 前端 (:3000) → Gateway (:8001)   [已配置 CORS]
                     → LangGraph (:2024)  [直连]
```

| 端口 | 服务 | 说明 |
|------|------|------|
| 3000 | Next.js 前端 | Web 界面，浏览器直接访问 |
| 2024 | LangGraph Server | Agent 运行时 |
| 8001 | Gateway API | REST API：模型管理、MCP 配置、记忆、技能 |
| 11434 | Ollama（可选） | 本地大模型服务 |

## 文档

| 文档 | 说明 |
|------|------|
| [Windows 部署指南](./docs/WINDOWS_DEPLOY.md) | 完整的 Windows 安装、配置和常见问题排查 |
| [配置指南](./backend/docs/CONFIGURATION.md) | 所有配置项说明（模型、工具、沙箱等） |
| [架构概览](./backend/CLAUDE.md) | 技术架构详细说明 |
| [贡献指南](./CONTRIBUTING.md) | 开发工作流（原版） |
| [MCP Server 指南](./backend/docs/MCP_SERVER.md) | MCP 服务器和技能配置 |

## 常见问题

| 问题 | 解决方案 |
|------|----------|
| 设置页面显示 "Failed to fetch" | 在 `backend/app/gateway/app.py` 添加 `CORSMiddleware`（见[部署指南](./docs/WINDOWS_DEPLOY.md)） |
| 工具页面为空 | 从示例文件创建 `extensions_config.json` |
| 端口被占用 | 运行 `.\scripts\stop.ps1` 或 `taskkill /F /PID <PID>` |
| 修改 `NEXT_PUBLIC_*` 后不生效 | 必须重启 Next.js 前端服务 |

完整排查指南请查看 [Windows 部署指南 - 常见问题](./docs/WINDOWS_DEPLOY.md#8-常见问题排查)。

## 原版项目

本项目基于以下开源项目改编：

- **仓库地址**：[bytedance/deer-flow](https://github.com/bytedance/deer-flow)
- **开源协议**：[MIT License](./LICENSE)（与原版一致）

所有核心源码、技能和 Agent 框架均保持原版不变，仅添加了平台适配和启动脚本。

## 开源协议

[MIT License](./LICENSE) — 与原版项目一致。
