# DeerFlow Windows 工具与技能清单

> 本文档列出 DeerFlow Windows 仓库中已安装和配置的所有工具、技能及其状态。
> 最后更新：2026-03-22

---

## 目录

- [总览](#总览)
- [一、内置工具（DeerFlow Agent）](#一内置工具deerflow-agent)
  - [1.1 沙箱工具](#11-沙箱工具)
  - [1.2 框架自动注册工具](#12-框架自动注册工具)
- [二、社区工具（可插拔替换）](#二社区工具可插拔替换)
  - [2.1 网页搜索后端](#21-网页搜索后端)
  - [2.2 网页抓取后端](#22-网页抓取后端)
- [三、MCP 工具服务器](#三mcp-工具服务器)
  - [3.1 已启用](#31-已启用)
  - [3.2 未启用（可选）](#32-未启用可选)
- [四、Agent 技能（Skills）](#四agent-技能skills)
- [五、WorkBuddy 技能（开发辅助）](#五workbuddy-技能开发辅助)
- [六、工具统计总览](#六工具统计总览)

---

## 总览

DeerFlow 的工具体系分为四层：

```
┌──────────────────────────────────────────────────────┐
│  Skills（技能工作流）                                   │
│  17 个预置技能：深度研究、PPT 生成、数据分析、图像生成...   │
├──────────────────────────────────────────────────────┤
│  MCP 工具服务器（可扩展外部工具）                          │
│  3 个已启用：filesystem + office-suite + mermaid        │
│  2 个可选：github + postgres                             │
├──────────────────────────────────────────────────────┤
│  社区工具（可插拔 web_search / web_fetch 替换）          │
│  5 种搜索后端 + 4 种抓取后端                             │
├──────────────────────────────────────────────────────┤
│  内置工具（核心能力）                                     │
│  5 个沙箱工具 + 6 个框架工具 = 11 个基础工具              │
└──────────────────────────────────────────────────────┘
```

---

## 一、内置工具（DeerFlow Agent）

### 1.1 沙箱工具

通过 `config.yaml` 的 `tools` 配置项管理，Agent 在执行任务时直接调用。

| 工具名 | 分组 | 功能 | 需要 API Key | 当前状态 |
|--------|------|------|-------------|---------|
| **bash** | `bash` | 在沙箱环境中执行命令（Python、pip、git 等） | 否 | ✅ 启用 |
| **ls** | `file:read` | 列出目录内容（最多 2 层深度） | 否 | ✅ 启用 |
| **read_file** | `file:read` | 读取文本文件（支持指定行范围） | 否 | ✅ 启用 |
| **write_file** | `file:write` | 写入文件（支持追加模式） | 否 | ✅ 启用 |
| **str_replace** | `file:write` | 替换文件中的字符串（支持全局替换） | 否 | ✅ 启用 |

**沙箱模式：** 默认使用 `LocalSandboxProvider`（本地直接执行）。也支持 Docker 容器隔离的 `AioSandboxProvider`。

**源文件：** `backend/packages/harness/deerflow/sandbox/tools.py`

### 1.2 框架自动注册工具

由 DeerFlow 框架自动注册，无需手动配置。

| 工具名 | 功能 | 说明 |
|--------|------|------|
| **view_image** | 读取并显示图片 | 支持 jpg/png/webp，需模型支持 vision |
| **present_files** | 将文件展示给用户 | 文件须在 `/mnt/user-data/outputs/` 目录下 |
| **task** | 委派子代理执行任务 | 支持 `general-purpose` 和 `bash` 两种类型 |
| **ask_clarification** | 向用户请求澄清 | 支持 5 种类型：missing_info / ambiguous / approach_choice / risk / suggestion |
| **setup_agent** | 创建自定义代理 | 通过 SOUL.md 定义代理人格 |
| **tool_search** | 延迟工具搜索 | 运行时发现 MCP 工具（需 `tool_search.enabled: true`） |

**源文件：** `backend/packages/harness/deerflow/tools/builtins/`

---

## 二、社区工具（可插拔替换）

`web_search` 和 `web_fetch` 支持多种后端实现，通过修改 `config.yaml` 中 `use` 字段切换。

### 2.1 网页搜索后端

| 后端 | 模块路径 | 需要 API Key | 当前状态 |
|------|---------|-------------|---------|
| **DuckDuckGo** | `deerflow.community.ddg_search.tools:web_search_tool` | ❌ 免费 | ✅ **当前使用** |
| **InfoQuest** | `deerflow.community.infoquest.tools:web_search_tool` | 需要 `INFOQUEST_API_KEY` | 未启用 |
| **Firecrawl** | `deerflow.community.firecrawl.tools:web_search_tool` | 需要 Firecrawl API Key | 未启用 |
| **Tavily** | `deerflow.community.tavily.tools:web_search_tool` | 需要 `TAVILY_API_KEY` | 未启用 |

> **Windows 改动：** 原版使用 Tavily（需付费），已替换为免费的 DuckDuckGo 搜索。

### 2.2 网页抓取后端

| 后端 | 模块路径 | 需要 API Key | 当前状态 |
|------|---------|-------------|---------|
| **Jina AI** | `deerflow.community.jina_ai.tools:web_fetch_tool` | 可选 `JINA_API_KEY`（提升速率） | ✅ **当前使用** |
| **InfoQuest** | `deerflow.community.infoquest.tools:web_fetch_tool` | 需要 `INFOQUEST_API_KEY` | 未启用 |
| **Firecrawl** | `deerflow.community.firecrawl.tools:web_fetch_tool` | 需要 Firecrawl API Key | 未启用 |
| **Tavily** | `deerflow.community.tavily.tools:web_fetch_tool` | 需要 `TAVILY_API_KEY` | 未启用 |

### 2.3 图片搜索

| 工具名 | 模块路径 | 需要 API Key | 当前状态 |
|--------|---------|-------------|---------|
| **image_search** | `deerflow.community.image_search.tools:image_search_tool` | ❌ 免费 | ✅ 启用 |

> 基于 DuckDuckGo 图片搜索，用于图片生成前的参考图查找。

---

## 三、MCP 工具服务器

通过 `extensions_config.json` 配置，遵循 MCP（Model Context Protocol）标准。

### 3.1 已启用

#### filesystem — 文件系统访问

| 属性 | 值 |
|------|-----|
| 运行方式 | `npx -y @modelcontextprotocol/server-filesystem` |
| 允许目录 | `d:/workAI`（可自定义） |
| 需要 API Key | 否 |
| 功能 | 在指定目录内读写文件、创建目录等 |

#### office-suite — Office 文档生成

| 属性 | 值 |
|------|-----|
| 来源 | [walkingzzzy/office-mcp](https://github.com/walkingzzzy/office-mcp) |
| 运行方式 | `python backend/mcp-servers/office-mcp/src/office_mcp_server/main.py` |
| 输出目录 | `d:/workAI/DeerFlow/output` |
| 需要 API Key | 否 |
| 安装依赖 | `pip install fastmcp python-docx openpyxl python-pptx reportlab scipy scikit-learn pandas numpy` |

**注册的 MCP 工具（共 201 个）：**

| 模块 | 功能类别 | 工具数量 |
|------|---------|---------|
| **Word (.docx)** | 基础操作、格式化、表格、图片、结构、编辑、引用、内容提取、批量操作、导入导出、高级功能、格式检查、批量格式化、页面设置、智能格式化、文档清理、教育模板 | **75** |
| **Excel (.xlsx)** | 基础操作、数据操作、格式化、结构、图表、导入导出、自动化、数据分析、协作、安全、打印 | **91** |
| **PowerPoint (.pptx)** | 基础操作、内容操作、格式化、媒体、动画、内容提取、批量操作 | **34** |
| **服务器信息** | 版本、支持的格式 | **1** |

#### mermaid — 图表生成

| 属性 | 值 |
|------|-----|
| 运行方式 | `npx -y mcp-mermaid` |
| 需要 API Key | 否 |
| 功能 | 将 Mermaid 语法渲染为 SVG/PNG 图片 |
| 支持的图表类型 | 流程图、时序图、ER 图、甘特图、思维导图、状态图、类图、Git 图等 |

### 3.2 未启用（可选）

#### github — GitHub 操作

| 属性 | 值 |
|------|-----|
| 运行方式 | `npx -y @modelcontextprotocol/server-github` |
| 需要 API Key | **是**（`GITHUB_TOKEN`） |
| 功能 | 仓库操作、Issues、PR、代码搜索等 |

启用方法：在 `extensions_config.json` 中将 `"enabled"` 改为 `true` 并设置 `GITHUB_TOKEN` 环境变量。

#### postgres — 数据库访问

| 属性 | 值 |
|------|-----|
| 运行方式 | `npx -y @modelcontextprotocol/server-postgres <connection_string>` |
| 需要 API Key | 需要数据库凭证 |
| 功能 | PostgreSQL 数据库查询和管理 |

---

## 四、Agent 技能（Skills）

Skills 是 Agent 工作流模板，通过 `SKILL.md` 定义行为指令。存放于 `skills/public/` 目录。

### 研究与分析

| 技能 | 描述 | 外部依赖 |
|------|------|---------|
| **deep-research** | 系统化的多角度深度网络研究方法论 | web_search + web_fetch |
| **data-analysis** | 分析 Excel/CSV 文件（SQL 查询、统计汇总） | DuckDB（内置） |
| **consulting-analysis** | 生成麦肯锡/BCG 标准的咨询级研究报告 | web_search + chart-visualization |
| **github-deep-research** | GitHub 仓库深度分析（API + 搜索 + 报告） | GitHub API + web_search |

### 内容生成

| 技能 | 描述 | 外部依赖 |
|------|------|---------|
| **ppt-generation** | 生成专业 PPT（含 AI 图片生成，5 种视觉风格） | 图片生成 API |
| **image-generation** | AI 图片生成（支持参考图引导） | 图片生成 API |
| **video-generation** | AI 视频生成（支持参考图） | 视频生成 API |
| **podcast-generation** | 文本转双人对话播客音频 | TTS API |

### 可视化与设计

| 技能 | 描述 | 外部依赖 |
|------|------|---------|
| **chart-visualization** | 数据可视化（26 种图表类型） | Node.js >= 18 |
| **frontend-design** | 创建高质量前端界面（HTML/CSS/React） | 无 |
| **web-design-guidelines** | 审查 UI 代码是否符合 Web 界面规范 | 网络（获取指南） |

### 开发工具

| 技能 | 描述 | 外部依赖 |
|------|------|---------|
| **skill-creator** | 创建/修改/优化技能，运行评估测试 | 无 |
| **find-skills** | 发现和安装社区技能 | 网络 |
| **vercel-deploy** | 部署应用到 Vercel（无需认证） | Vercel |
| **claude-to-deerflow** | 通过 HTTP API 与 DeerFlow 交互 | 运行中的 DeerFlow 实例 |

### 其他

| 技能 | 描述 | 外部依赖 |
|------|------|---------|
| **bootstrap** | 通过对话生成个性化 SOUL.md（代理人格配置） | 无 |
| **surprise-me** | 创意组合可用技能，制造惊喜体验 | 取决于组合的技能 |

---

## 五、WorkBuddy 技能（开发辅助）

以下技能安装于 WorkBuddy 客户端，在开发过程中为用户提供辅助能力（非 DeerFlow Agent 使用）。

| 技能 | 来源 | 功能 |
|------|------|------|
| **docx** | 内置 plugin | Word 文档创建、编辑、读取 |
| **xlsx** | 内置 plugin | Excel 表格创建、编辑、数据分析 |
| **pptx** | 内置 plugin | PowerPoint 演示文稿创建和编辑 |
| **pdf** | 内置 plugin | PDF 读取、合并、拆分、水印等 |
| **image-enhancer** | 内置 plugin | 图像增强处理 |
| **mermaid-diagrams** | 用户级技能 | Mermaid 图表生成（Markdown 嵌入） |

---

## 六、工具统计总览

| 类别 | 数量 |
|------|------|
| 沙箱工具（config.yaml 可配） | 5 |
| 框架自动注册工具 | 6 |
| 社区搜索后端（可替换） | 4 种 |
| 社区抓取后端（可替换） | 4 种 |
| 已启用 MCP 服务器 | 3 个 |
| 未启用 MCP 服务器 | 2 个 |
| MCP 工具（office-suite） | ~201 个 |
| Agent 技能（Skills） | 17 个 |
| **工具总计（含 MCP 子工具）** | **~230+** |

---

## 配置文件参考

| 文件 | 用途 |
|------|------|
| `config.yaml` | 主配置：模型、工具、沙箱、记忆、检查点等 |
| `extensions_config.json` | MCP 服务器和技能配置 |
| `extensions_config.example.json` | MCP 配置模板（新用户复制使用） |

## 相关文档

- [Windows 部署指南](./WINDOWS_SETUP.md) — 完整安装步骤
- [Windows 部署说明](./WINDOWS_DEPLOY.md) — 精简部署说明
