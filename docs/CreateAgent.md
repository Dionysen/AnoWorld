# 创作 Agent 与 Tool Registry

应用内创作能力通过 **Tool Registry** 统一调用，不经 MCP。创作助手浮窗按「编辑目标」走 [`CreateAgentRunner.runTurn`](../lib/domain/ai/create/create_agent_runner.dart) → 域内工具白名单 → 确认后落盘。

## 已实现工具

| Tool | 作用 |
| --- | --- |
| `card.list_sources` | 导入草稿素材片段 |
| `card.sanitize_draft` | 去 HTML，保留 Markdown |
| `card.organize_propose` | AI 分类整理提议（模型优先；无用或误拆时回退通用启发式） |
| `card.organize_apply` | 应用整理 JSON（子串校验） |
| `project.validate` | 结构校验 |
| `project.read_summary` | 故事概览 |
| `world.list_entries` / `world.read_entry` | 渐进读设定 |
| `world.patch_propose` | 增量改世界书（`userConfirmRequired`） |
| `cast.list_members` / `cast.read_member` | 渐进读角色 |
| `cast.patch_propose` | 增量改角色（`userConfirmRequired`） |
| `main.read_graph` | 主线紧凑骨架 |
| `main.generate_graph` | 整图写情节骨架（至少约 20 站；`userConfirmRequired`） |
| `main.patch_graph` | 增量改情节骨架（ops；`userConfirmRequired`） |
| `refine.field` | 占位 |
| `ingest.segment` | 占位 |

代码：`lib/domain/ai/create/`、`lib/domain/card_import/card_*`、补丁 apply 在 `lib/domain/main/apply_*_patch.dart`。

## 创作助手（通用 Agent）

- UI：[`CreateAssistantPanel`](../lib/home/create_assistant_panel.dart) 选当前故事 + **改哪里**（情节图 / 世界书 / 角色），见 [`CreateAssistantTarget`](../lib/domain/ai/create/create_assistant_target.dart)。
- 回合：`runTurn(target, prompt)` 规则挑工具（有图且非「整图重写」→ `main.patch_graph`；世界书/角色 → 对应 `patch_propose`）。
- 确认：半屏预览后写回；情节图全量替换会提示清掉旧站；增量只应用 ops。
- 全量骨架规则：≥20 站、上不封顶；分叉 synopsis 互斥；开放叶可无出边；剧情元素按分类注入。见 [`CreatePromptProfiles`](../lib/domain/ai/create/create_prompt_profiles.dart)。

## 格式

- 世界书 / 角色正文：**Markdown 存盘**，HTML 不落库。
- 导入预览可用 [`AppMarkdown`](../lib/foundation/widgets/app_markdown.dart)；游玩聊天气泡仍为纯文本。

## 未做

- 完整多轮 LLM tool-loop、跨域一次改多处、`refine.field` 精修。
