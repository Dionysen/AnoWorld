# 创作 Agent 与 Tool Registry

应用内创作能力通过 **Tool Registry** 统一调用，不经 MCP。UI / 将来的创作助手浮窗只调 `CreateAgentRunner` → `CreateToolRegistry.invoke`。

## P0（已实现）

| Tool | 作用 |
| --- | --- |
| `card.list_sources` | 导入草稿素材片段 |
| `card.sanitize_draft` | 去 HTML，保留 Markdown |
| `card.organize_propose` | AI 分类整理提议（模型优先；无用或误拆时回退通用启发式：原文锚点 + 叙述行） |
| `card.organize_apply` | 应用整理 JSON（子串校验） |
| `project.validate` | 结构校验 |
| `project.read_summary` | 故事概览 |
| `world.list_entries` / `world.read_entry` | 渐进读设定 |
| `cast.list_members` / `cast.read_member` | 渐进读角色 |
| `main.read_graph` | 主线紧凑骨架 |
| `main.generate_graph` | 按世界书 + 提示词写情节骨架（`userConfirmRequired`，返回摘要 / 站点 / 图；不落盘） |
| `refine.field` | 占位 |
| `ingest.segment` | 占位 |

代码：`lib/domain/ai/create/`、`lib/domain/card_import/card_*`。

## 格式

- 世界书 / 角色正文：**Markdown 存盘**，HTML 不落库。
- 导入预览可用 [`AppMarkdown`](../lib/foundation/widgets/app_markdown.dart)；游玩聊天气泡仍为纯文本。

## P1（进行中）

- 创作助手浮窗：绑定「当前故事」，输入一句走向 → `main.generate_graph` → 半屏预览确认 → 写回 `main`（有旧情节时提示替换）。实现见 [`GenerateMainGraphAction`](../lib/domain/ai/generate_main_graph_action.dart) 与 [`CreateAssistantPanel`](../lib/home/create_assistant_panel.dart)。
- 意图路由（自由对话挑工具）、`refine.field` 等其余能力未做。