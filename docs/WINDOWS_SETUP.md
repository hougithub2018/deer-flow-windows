# DeerFlow Windows 10/11 部署指南

本文档描述如何在全新的 Windows 10/11 系统上从零部署和运行 DeerFlow。

---

## 一、安装系统依赖

### 1.1 安装 PowerShell 7+（如果尚未安装）

Windows 10/11 自带的 PowerShell 5.1 可以使用，但推荐安装 PowerShell 7+ 获得更好兼容性。

从 [GitHub Releases](https://github.com/PowerShell/PowerShell/releases) 下载 `PowerShell-7.x.x-win-x64.msi` 安装。

验证：
```powershell
pwsh --version
```

### 1.2 安装 Git

下载安装 [Git for Windows](https://git-scm.com/download/win)，安装时勾选 "Add to PATH"。

```powershell
git --version
```

### 1.3 安装 Python 3.11+

从 [python.org](https://www.python.org/downloads/) 下载安装，**安装时务必勾选 "Add python.exe to PATH"**。

```powershell
python --version
```

### 1.4 安装 Node.js 22+

从 [nodejs.org](https://nodejs.org/) 下载 LTS 版本（22.x），安装时勾选 "Add to PATH"。

```powershell
node --version
```

### 1.5 安装 pnpm

```powershell
npm install -g pnpm
pnpm --version
```

### 1.6 安装 uv（Python 包管理器）

```powershell
pip install uv
uv --version
```

### 1.7 安装 Ollama（本地 LLM 推理，可选但推荐）

从 [ollama.com](https://ollama.com/download) 下载 Windows 版安装。

安装后拉取所需模型，例如：
```powershell
ollama pull glm-5:cloud
ollama pull qwen3.5:27b
```

### 1.8 安装 nginx（可选）

Windows 下 nginx **非必需**，可以跳过。如需安装，从 [nginx.org](https://nginx.org/en/download.html) 下载 zip 包解压即可。

---

## 二、允许 PowerShell 执行本地脚本

首次运行 `.ps1` 脚本前需要解除执行限制（只需执行一次）：

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

这允许运行本地脚本，不会降低安全性。

---

## 三、获取项目代码

```powershell
git clone <你的仓库地址> deer-flow20
cd deer-flow20
```

---

## 四、检查依赖

```powershell
python scripts\check.py
```

期望输出：
```
==========================================
  Checking Required Dependencies
==========================================

Checking Node.js...
  [OK] Node.js 24.14.0 (>= 22 required)

Checking pnpm...
  [OK] pnpm 10.32.0

Checking uv...
  [OK] uv 0.x.x

Checking nginx...
  [WARN] nginx not found (optional on Windows)
    ...

==========================================
  All dependencies are installed!
==========================================
```

---

## 五、安装项目依赖

```powershell
.\scripts\install.ps1
```

这个脚本会自动：
- `cd backend && uv sync` — 安装 Python 后端依赖
- `cd frontend && pnpm install` — 安装 Node.js 前端依赖

---

## 六、生成配置文件

```powershell
python scripts\configure.py
```

这会从 `config.example.yaml` 复制生成 `config.yaml`、`.env`、`frontend/.env`。

---

## 七、配置 LLM 模型

编辑项目根目录的 `config.yaml`，在 `models:` 部分配置你的模型。

### 7.1 使用本地 Ollama 模型

```yaml
models:
  - name: glm-5-cloud
    display_name: GLM-5 Cloud (Ollama)
    use: langchain_openai:ChatOpenAI
    model: glm-5:cloud
    base_url: http://localhost:11434/v1
    api_key: ollama
    max_tokens: 8192
    temperature: 0.7

  - name: qwen3.5-27b
    display_name: Qwen 3.5 27B (Ollama)
    use: langchain_openai:ChatOpenAI
    model: qwen3.5:27b
    base_url: http://localhost:11434/v1
    api_key: ollama
    max_tokens: 8192
    temperature: 0.7
```

### 7.2 使用云端 API 模型

取消注释 `config.yaml` 中对应的示例并填入 API Key，例如：

```yaml
models:
  - name: gpt-4
    display_name: GPT-4
    use: langchain_openai:ChatOpenAI
    model: gpt-4
    api_key: $OPENAI_API_KEY    # 或直接填写 key
    max_tokens: 4096
```

也可以在 `.env` 文件中设置 API Key：
```
OPENAI_API_KEY=sk-xxxxxxxxxxxxx
```

> **注意**：`models` 列表中的第一个模型为默认模型。

---

## 八、安装 MCP 工具（文档生成与图表）

DeerFlow 支持 MCP（Model Context Protocol）工具扩展。以下为推荐的 MCP 工具。

### 8.1 克隆 Office MCP Server

```powershell
git clone https://github.com/walkingzzzy/office-mcp.git backend\mcp-servers\office-mcp
```

### 8.2 安装 Python 依赖

```powershell
pip install fastmcp python-docx openpyxl python-pptx reportlab Pillow scipy scikit-learn pandas numpy loguru
```

### 8.3 生成 MCP 配置文件

```powershell
copy extensions_config.example.json extensions_config.json
```

然后编辑 `extensions_config.json`，将路径修改为你的实际项目路径：

```json
{
  "mcpServers": {
    "filesystem": {
      "enabled": true,
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "d:/your/work/path"],
      "env": {},
      "description": "Filesystem access"
    },
    "office-suite": {
      "enabled": true,
      "type": "stdio",
      "command": "cmd",
      "args": ["/c", "python", "backend/mcp-servers/office-mcp/src/office_mcp_server/main.py"],
      "env": {
        "PYTHONPATH": "backend/mcp-servers/office-mcp/src",
        "OUTPUT_DIR": "output"
      },
      "description": "Office document generation: Word, Excel, PowerPoint, PDF"
    },
    "mermaid": {
      "enabled": true,
      "type": "stdio",
      "command": "cmd",
      "args": ["/c", "npx", "-y", "mcp-mermaid"],
      "env": {},
      "description": "Generate Mermaid diagrams as SVG/PNG"
    }
  },
  "skills": {}
}
```

### 8.4 创建输出目录

```powershell
New-Item -ItemType Directory -Path output -Force
```

### 8.5 可用的 MCP 工具

| 工具 | 功能 | 依赖 |
|---|---|---|
| **filesystem** | 文件系统读写访问 | npx |
| **office-suite** | Word/Excel/PPT/PDF 文档生成与编辑 | Python（见 8.2） |
| **mermaid** | 流程图、序列图、ER 图等图表生成 | npx |

---

## 九、启动开发服务器

```powershell
.\scripts\dev.ps1
```

脚本会依次启动：
1. **LangGraph Server** (localhost:2024) — 后端 Agent 服务
2. **Gateway API** (localhost:8001) — API 网关
3. **Frontend** (localhost:3000) — Next.js 前端界面

启动成功后访问：**http://localhost:3000**

生产模式启动：
```powershell
.\scripts\dev.ps1 -Prod
```

---

## 十、停止服务

```powershell
.\scripts\stop.ps1
```

或在运行 dev.ps1 的窗口中按 `Ctrl+C`。

---

## 十一、日常操作速查

| 操作 | 命令 |
|---|---|
| 检查依赖 | `python scripts\check.py` |
| 安装依赖 | `.\scripts\install.ps1` |
| 生成配置 | `python scripts\configure.py` |
| 升级配置 | `python scripts\config_upgrade.py` |
| 启动服务 | `.\scripts\dev.ps1` |
| 启动(生产) | `.\scripts\dev.ps1 -Prod` |
| 停止服务 | `.\scripts\stop.ps1` |
| 查看日志 | `Get-Content logs\langgraph.log -Tail 50` |

---

## 十二、服务端口说明

| 服务 | 端口 | 说明 |
|---|---|---|
| Frontend | 3000 | Next.js 前端 |
| Gateway API | 8001 | API 网关 |
| LangGraph | 2024 | Agent 后端 |
| nginx | 2026 | 反向代理（可选） |

---

## 十三、常见问题

### Q: 运行 `.\scripts\dev.ps1` 提示 "无法加载文件...禁止运行脚本"
执行 `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` 后重试。

### Q: 端口被占用无法启动
运行 `.\scripts\stop.ps1`，如果还报端口占用，关闭所有 PowerShell 窗口后重新打开。

### Q: LangGraph 启动后界面无法对话
1. 确认 Ollama 正在运行：`ollama list`
2. 确认 `config.yaml` 中的 `base_url` 指向正确的 Ollama 地址
3. 查看日志：`Get-Content logs\langgraph.log -Tail 30`

### Q: Windows 控制台显示乱码
check.py 已自动处理 UTF-8 编码。如果仍有问题，在 PowerShell 中执行：
```powershell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
```
