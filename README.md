# 🦌 DeerFlow 2.0 — Windows Native

> **A Windows 10/11 native adaptation** of [bytedance/deer-flow](https://github.com/bytedance/deer-flow). No Docker, no nginx — just run it directly.

English | [中文](./README_zh.md)

[![Python](https://img.shields.io/badge/Python-3.12%2B-3776AB?logo=python&logoColor=white)](./backend/pyproject.toml)
[![Node.js](https://img.shields.io/badge/Node.js-22%2B-339933?logo=node.js&logoColor=white)](./Makefile)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D6?logo=windows&logoColor=white)](./docs/WINDOWS_DEPLOY.md)

## What is This?

[DeerFlow](https://github.com/bytedance/deer-flow) is an open-source super agent harness by ByteDance, built on LangGraph and LangChain. It orchestrates sub-agents, memory, sandboxes, skills, and tools to accomplish complex tasks like deep research, report generation, slide creation, and more.

**This repository** is a Windows-native adaptation of DeerFlow 2.0. The upstream project assumes a Docker + nginx environment (Linux/macOS), which creates a high barrier for Windows users. This fork removes that barrier with minimal, targeted changes — no Docker, no nginx, no WSL required.

### What Changed?

| # | File | Change | Why |
|---|------|--------|-----|
| 1 | `frontend/.env` | Uncomment `NEXT_PUBLIC_BACKEND_BASE_URL` and `NEXT_PUBLIC_LANGGRAPH_BASE_URL` | Enable direct frontend → backend connection, bypassing nginx |
| 2 | `backend/app/gateway/app.py` | Add `CORSMiddleware` | Upstream handles CORS via nginx; direct mode needs it in FastAPI |
| 3 | `extensions_config.json` | Created from example, enabled filesystem MCP | Without this file, the Tools settings page is empty |
| 4 | `backend/.../config/paths.py` | Skip `chmod 0o777` on Windows | `chmod` is a no-op on Windows and can cause issues |
| 5 | `backend/.../sandbox/local/local_sandbox.py` | Detect `cmd.exe` as shell on Windows | Upstream only looks for Unix shells |
| 6 | `backend/.../sandbox/tools.py` | Add Windows system path prefixes | Allow recognition of Windows paths like `C:\Windows\System32\` |
| 7 | `scripts/check.py` | Fix Unicode output and `shell=True` on Windows | GBK console encoding breaks Unicode symbols like ✓ |
| 8 | `scripts/dev.ps1`, `stop.ps1`, `install.ps1` | Added (PowerShell scripts) | Upstream only provides `Makefile` for Unix shells |

**No source code of the core agent framework was modified.** All changes are platform adaptation in configuration, shell detection, and startup scripts.

## Quick Start

### Prerequisites

| Software | Version | Install |
|----------|---------|---------|
| Node.js | 22+ | https://nodejs.org/ |
| pnpm | Latest | `npm install -g pnpm` |
| uv | Latest | https://docs.astral.sh/uv/getting-started/installation/ |
| Python | 3.12+ | Managed automatically by `uv` |

> Docker and nginx are **not required**. Ollama is optional (for local LLMs).

### 1. Clone & Install

```powershell
git clone https://github.com/hougithub2018/deer-flow-windows.git
cd deer-flow-windows

# Install dependencies
.\scripts\install.ps1
```

### 2. Configure

```powershell
# Generate config files from templates
python scripts\configure.py
```

Then edit the generated files:

**`config.yaml`** — Add at least one model:
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

**`.env`** — Set your API keys:
```env
DEEPSEEK_API_KEY=sk-xxxxxxxxxxxxx
TAVILY_API_KEY=tvly-xxxxxxxxxxxxx
```

### 3. Enable MCP Extensions (Optional)

```powershell
copy extensions_config.example.json extensions_config.json
```

Edit `extensions_config.json` to enable the MCP servers you need (filesystem, GitHub, etc.).

### 4. Run

```powershell
.\scripts\dev.ps1
```

Open **http://localhost:3000** in your browser. That's it.

### Stop

```powershell
.\scripts\stop.ps1
```

## Architecture

### Upstream (requires nginx)

```
Browser → nginx (:2026) → Frontend (:3000)
                        → Gateway (:8001)
                        → LangGraph (:2024)
```

### This Fork (direct connection)

```
Browser → Frontend (:3000) → Gateway (:8001)   [CORS configured]
                          → LangGraph (:2024)  [direct]
```

| Port | Service | Description |
|------|---------|-------------|
| 3000 | Next.js Frontend | Web UI — open in browser |
| 2024 | LangGraph Server | Agent runtime |
| 8001 | Gateway API | REST API: models, MCP, memory, skills |
| 11434 | Ollama (optional) | Local LLM server |

## Documentation

| Document | Description |
|----------|-------------|
| [Windows Deploy Guide](./docs/WINDOWS_DEPLOY.md) | Complete Windows setup, config, and troubleshooting |
| [Configuration Guide](./backend/docs/CONFIGURATION.md) | All config options (models, tools, sandbox, etc.) |
| [Architecture Overview](./backend/CLAUDE.md) | Technical architecture details |
| [Contributing Guide](./CONTRIBUTING.md) | Development workflow (upstream) |
| [MCP Server Guide](./backend/docs/MCP_SERVER.md) | MCP server and skills setup |

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Settings pages show "Failed to fetch" | Add `CORSMiddleware` to `backend/app/gateway/app.py` (see [guide](./docs/WINDOWS_DEPLOY.md)) |
| Tools page is empty | Create `extensions_config.json` from the example file |
| Port already in use | Run `.\scripts\stop.ps1` or `taskkill /F /PID <PID>` |
| `NEXT_PUBLIC_*` changes not taking effect | Must restart Next.js after modifying `frontend/.env` |

For full troubleshooting, see the [Windows Deploy Guide](./docs/WINDOWS_DEPLOY.md#8-常见问题排查).

## Upstream Project

This project is based on and extends:

- **Repository**: [bytedance/deer-flow](https://github.com/bytedance/deer-flow)
- **License**: [MIT License](./LICENSE) (same as upstream)

All core source code, skills, and agent framework remain unchanged from the upstream. Only platform adaptation and startup scripts have been added.

## License

[MIT License](./LICENSE) — same as the upstream project.
