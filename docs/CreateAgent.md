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

代码：`lib/domain/ai/create/`、`lib/domain/card_import/card_*`、补丁 apply 在 `lib/domain/main/apply_*_patch.dart`。

## 创作助手（通用 Agent）

- UI：[`CreateAssistantPanel`](../lib/home/create_assistant_panel.dart) 顶部只放「当前故事」选择（取代原来的「创作助手」标题）；编辑范围（情节图 / 世界书 / 角色 / 全部）是输入框右侧、发送键左边的四个图标按钮（`AppIconSegmented`，文字只作 tooltip），见 [`CreateAssistantTarget`](../lib/domain/ai/create/create_assistant_target.dart)。
- 回合：`runTurn(target, prompt)` 走 [`CreateAgentLoop`](../lib/domain/ai/create/create_agent_loop.dart)——注入五层 L1 目录（含预设段名与启用状态，预设只读）与该目标的工具，模型自己读（`*.read_*` / `main.read_graph`）、自己写（`main.replace` / `main.patch` / `*.patch`），最多 10 步。选工具不再靠关键词，读工具真正会被调用。
- 白名单：所有读工具 + 当前目标的写工具；选「全部」时五个写工具全开。读可跨层；单层目标仍只写自己那层。剧情元素是例外的一半：`plot.list_elements` 所有目标可读，`plot.select`（勾选 / 新增）挂在情节图与「全部」上。
- 工具名：内部与日志用带点的规范名（`world.patch`），发给模型时换成下划线（`world_patch`）——OpenAI 兼容网关要求 `tools[].function.name` 匹配 `^[a-zA-Z0-9_-]+$`，带点会直接 400。注册表两种叫法都认，回放 `tool_calls` 时也写成下划线。
- 跨层：提议不再结束回合，而是按层暂存（同一层重复提交会合并 ops 再校验），模型收到「已暂存，可继续」的 tool 结果后可以接着写别的层；回合结束时把这一批一起交给面板。
- 大图分批：一次写工具装不下 60 站（推理模型的思考也算在输出上限里）。先 `main.replace` 交开头一批，后续 `main.patch` 会跑在**已暂存的图上**，最后仍合成一条整图确认行——不会出现「整图替换 + 局部补丁」两份互相覆盖的提议。
- 工具参数容错：模型常在中文里写未转义的 `"`（`"synopsis":"同门唤他"扫地的""`），严格 JSON 解析会失败。`decodeTolerantJson`（[`tolerant_json.dart`](../lib/foundation/ai/tolerant_json.dart)）只修字符串内多余的引号与裸换行；真的被截断仍判失败，并把「参数不是合法 JSON」回给模型让它减少一批重提，不再拿空参数去调工具报「缺字段」。
- 输出上限：`finish_reason=length` 时，工具循环按真实原因报错（不再是一句「没有内容」），并**自动改小批重试**（`maxTruncationRetries` = 2，提示「这次只交 10～15 站」）。思考型模型每次先花 2～4k token 推理，8k 上限几乎必然截断 60 站大图——设置里 **单次最长输出** 已放开到 32768（[`AiGenerationSettingsPanel`](../lib/settings/ai_generation_settings_panel.dart)）。
- 对话记忆：面板把当前故事最近 10 条对话（用户能看到的那种气泡，不含「正在写」占位）随回合送进模型，`CreateAgentLoop` 再按剩余预算从旧到新丢，所以「再冷一点」有指代。换故事时旧对话仍留在屏幕上，但不再喂给模型。工具调用与工具结果不跨回合重放。
- 确认：半屏抽屉按层分组（世界书 / 角色 / 情节图 / 剧情元素），逐项勾选，确认后**一次 `repo.save`** 写回所有层；剧情元素库的新行先落设置再存故事。整图替换占一行，并明说会清掉旧站；增量只应用勾选的 ops。
- 模型不支持工具时：先把它回的文本当 JSON 改动解析（骨架 / ops），能解析就照常进确认抽屉，否则作为普通回答显示。「全部」目标的文本兜底按 op 名判断层（`upsert_entry` / `upsert_member` / `select`…）。
- 全量骨架规则：≥20 站、上不封顶；分叉 synopsis 互斥；开放叶可无出边；剧情元素按分类注入。见 [`CreatePromptProfiles`](../lib/domain/ai/create/create_prompt_profiles.dart)。

## 格式

- 世界书 / 角色正文：**Markdown 存盘**，HTML 不落库。
- 导入预览可用 [`AppMarkdown`](../lib/foundation/widgets/app_markdown.dart)；游玩聊天气泡仍为纯文本。

## 未做

- 剧情元素库里**已有条目**的正文改写：助手只能勾选或新增，改写走设置页。
- 拍与对白不归助手管：它们是运行时由 AI 现场生成的，创作层只到站与连线的概括。见 [AgentTools.md](./AgentTools.md) §8。

单字段润色不需要单独工具：读 `ref:` 拿到原文、模型改写、`*.patch` 只提交那一个字段即可，写工具本身不再嵌套调模型。

已做但曾列在此处的：聊天侧命中注入（[AgentTools.md](./AgentTools.md) §6.2）、上下文预算裁剪（§6.3）、五块的渐进披露与统一寻址（§5）。
