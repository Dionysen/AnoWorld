# 创作 Agent 与 Tool Registry

应用内创作能力通过 **Tool Registry** 统一调用，不经 MCP。创作助手浮窗按「编辑目标」走 [`CreateAgentRunner.runTurn`](../lib/domain/ai/create/create_agent_runner.dart) → 域内工具白名单 → 确认后落盘。

## 已实现工具

| Tool | 作用 |
| --- | --- |
| `card.list_sources` | 导入草稿素材片段 |
| `card.sanitize_draft` | 去 HTML，保留 Markdown |
| `project.validate` | 结构校验 |
| `project.read_summary` | 故事概览 |
| `world.list_entries` / `world.read_entry` | 渐进读设定（list 默认 50 条，可 `keyword` / `limit`） |
| `world.patch` | 提交世界书条目改动（`userConfirmRequired`） |
| `cast.list_members` / `cast.read_member` | 渐进读角色 |
| `cast.patch` | 提交角色改动（`userConfirmRequired`） |
| `plot.list_elements` | 列全局剧情元素库（id / 分类 / 关键词 / 一句说明 / 是否已选） |
| `plot.select` | 勾选 / 取消勾选，或新增一条并勾上（`userConfirmRequired`） |
| `main.read_graph` | 主线紧凑骨架 |
| `main.list_nodes` / `main.get_node` | 只列站 / 细看一站（概括、出入连线，支持 `node:<id>.<field>`） |
| `main.replace` | 提交整图骨架（至少约 20 站；`userConfirmRequired`） |
| `main.patch` | 提交情节图局部 ops（`userConfirmRequired`） |
| `refine.field` | 占位 |
| `ingest.segment` | 占位 |

代码：`lib/domain/ai/create/`、`lib/domain/card_import/card_*`、补丁 apply 在 `lib/domain/main/apply_*_patch.dart`。

## 创作助手（通用 Agent）

- UI：[`CreateAssistantPanel`](../lib/home/create_assistant_panel.dart) 选当前故事 + **改哪里**（情节图 / 世界书 / 角色），见 [`CreateAssistantTarget`](../lib/domain/ai/create/create_assistant_target.dart)。
- 回合：`runTurn(target, prompt)` 走 [`CreateAgentLoop`](../lib/domain/ai/create/create_agent_loop.dart)——注入五层 L1 目录（含预设段名与启用状态，预设只读）与该目标的工具，模型自己读（`*.read_*` / `main.read_graph`）、自己写（`main.replace` / `main.patch` / `*.patch`），最多 6 步。选工具不再靠关键词，读工具真正会被调用。
- 白名单：所有读工具 + 当前目标的写工具；读可跨层，写只能改当前层。剧情元素是例外的一半：`plot.list_elements` 所有目标可读，`plot.select`（勾选 / 新增）只挂在情节图目标下。
- 对话记忆：面板把当前故事最近 10 条对话（用户能看到的那种气泡，不含「正在写」占位）随回合送进模型，`CreateAgentLoop` 再按剩余预算从旧到新丢，所以「再冷一点」有指代。换故事时旧对话仍留在屏幕上，但不再喂给模型。工具调用与工具结果不跨回合重放。
- 确认：半屏预览后写回；情节图整包替换会提示清掉旧站；增量只应用勾选的 ops。
- 模型不支持工具时：先把它回的文本当 JSON 改动解析（骨架 / ops），能解析就照常进确认抽屉，否则作为普通回答显示。
- 全量骨架规则：≥20 站、上不封顶；分叉 synopsis 互斥；开放叶可无出边；剧情元素按分类注入。见 [`CreatePromptProfiles`](../lib/domain/ai/create/create_prompt_profiles.dart)。

## 格式

- 世界书 / 角色正文：**Markdown 存盘**，HTML 不落库。
- 导入预览可用 [`AppMarkdown`](../lib/foundation/widgets/app_markdown.dart)；游玩聊天气泡仍为纯文本。

## 未做

- `refine.field` 精修（当前只有占位）；跨域一次改多处（写仍只限当前目标层）。
- 剧情元素库里**已有条目**的正文改写：助手只能勾选或新增，改写走设置页。
- 拍与对白不归助手管：它们是运行时由 AI 现场生成的，创作层只到站与连线的概括。见 [AgentTools.md](./AgentTools.md) §8。

已做但曾列在此处的：聊天侧命中注入（[AgentTools.md](./AgentTools.md) §6.2）、上下文预算裁剪（§6.3）、五块的渐进披露与统一寻址（§5）。
