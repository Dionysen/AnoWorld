# Agent 工具化与渐进披露（设计稿）

**状态**：设计稿，未实现。正文为目标行为；§1 是仓库现状，§8 列出动手前需要拍板的问题。

本文讨论一件事：**预设、世界书、角色、情节图、剧情元素**这五块上下文，如何从「每次都全文塞进提示词」改成「给 AI 一张索引，按需取用并就地修改」。

---

## 0. 一句话

现在的做法是每次把整本设定集复印一份放在 AI 面前；目标是给它一张图书馆索引卡，它想看哪本再借哪本，改完能按编号精确还回原位。

---

## 1. 现状（截至本稿）

### 1.1 五块上下文当前怎么进模型

| 模块 | 聊天时 | 创作时 |
| --- | --- | --- |
| 预设 | 全部启用段拼进 system | 同聊天 |
| 世界书 | **全文**（`WorldBook.combinedText`） | 全文塞进 user 消息 |
| 角色 | 主角字段进宏；配角**只有名字** | 全部字段塞进 user 消息 |
| 情节图 | 摘要 + 当前站 synopsis + 前 6 站标题 | **整份骨架 JSON**（含 layout 以外全部字段） |
| 剧情元素 | 已选条目**全部描述**拼成一块 | 同聊天 |

落点：`lib/domain/ai/ai_prompt_context.dart`、`lib/domain/settings/plot_element_catalog.dart`（`promptBlockForSelected`）。

**结构上只有情节图做了压缩，其余四块都是无条件全给。**

### 1.2 已被写进注释、但没实现的机制

世界书条目本来带关键词字段，注释描述的用途很明确：

```1:15:lib/domain/models/world_book.dart
  /// Plain keywords that can pull this entry into bridge context.
  final List<String> keys;
```

但仓库内除读取工具与导入映射外，**没有任何代码拿 `keys` 做匹配注入**。这是现成可用的钩子，不是要新造的东西。

### 1.3 已有的工具骨架

`lib/domain/ai/create/` 下已经有一套工具注册表，命名风格是 `域.动作`：

- 读：`world.list_entries`、`world.read_entry`、`cast.list_members`、`cast.read_member`、`main.read_graph`
- 写：`world.patch_propose`、`cast.patch_propose`、`main.patch_graph`、`main.generate_graph`
- 补丁落地：`lib/domain/main/apply_*_patch.dart`，按 `id` 合并，缺省字段沿用旧值

这套东西**方向是对的**，问题在于：

1. 回合是规则挑工具（`CreateAgentRunner._pickTool`），不是模型自己选。
2. 一次性单步，没有「先读 → 再判断 → 再改」的多步循环。
3. 读工具登记了但从不被调用，形同虚设。

### 1.4 三个硬缺口

**A. HTTP 层没有工具调用通道。**

```66:70:lib/foundation/ai/openai_chat_client.dart
    final body = <String, dynamic>{
      'model': model.trim(),
      'messages': messages.map((m) => m.toJson()).toList(growable: false),
```

请求体没有 `tools`；消息模型只有 `role` + `content`；响应只读 `message.content`，不读 `tool_calls`。**不补这一层，下面的设计全部无处落地。**（阶段 0 已补，见 §7.1。）

**B. 没有上下文预算裁剪。**

`GenerationPreset.contextLength` 只被存取与展示，既不随请求发送，也无人用它裁剪。按需披露若没有预算约束，收益会被「反正还是全塞」抵消。

**C. 意图靠字符串匹配。**

`CreateAgentRunner.wantsFullGraphRewrite` 用硬编码中文关键词判断「整图重写」。工具化之后这个判断应交还给模型。

---

## 2. 目标

1. **可寻址**：五块数据都有稳定的地址，AI 能精确说出「改哪一条、哪个字段」。
2. **可披露**：给 AI 的是索引（小），详情按需取（大）。三层深度：目录 → 条目 → 字段。
3. **可操作**：增删查改走固定格式，不靠自然语言复述整份数据。
4. **可收敛**：任何一次读或写都受 token 预算与结构校验约束。

非目标：不做无限开放世界聊天；不引入进程间协议；不把预设外置成插件。

---

## 3. 分层模型

每一块上下文都拆成**三个深度**，正好对应渐进披露的三步：

| 深度 | 内容 | 大致体量 | 出现在哪 |
| --- | --- | --- | --- |
| L1 目录 | 条目的 id + 标题 + 一行摘要 | 每条约 10~20 token | 默认注入，随任务发生 |
| L2 条目 | 单条完整正文 | 一条几十到几百 token | AI 调 `get` 取 |
| L3 字段 | 单条内某个字段 | 极小 | AI 调 `get` 指定字段 |

举例：

- 世界书 L1 = `wb_03 · 潮汐公约`；L2 = 正文全文；L3 = `.keys` 或 `.body`
- 角色 L1 = `c_02 · 林晚 · 沉默的药剂师`；L2 = 档案全文；L3 = `.speechStyle`
- 情节图 L1 = 站点标题 + 出边数；L2 = 单站 synopsis 与其出边详情；L3 = 某条边的 `.detail`

**关键约束**：L1 必须足够小，小到「全量 L1」也能放进预算。这是整个方案成立的前提。

---

## 4. 统一寻址

现在 id 各自为政（`wb_p_3`、`c_p_2`、`n_p_5`、`e_p_1`），没有统一的引用语法。已补一层**引用字符串**，只作为 AI 与工具之间的地址，不改落盘结构：

```text
预设          preset:<presetId>
世界书条目    wb:<entryId>
角色          cast:<memberId>
情节站        node:<nodeId>
连线          edge:<edgeId>
剧情元素      pe:<elementId>
```

字段用点号续写：`wb:wb_03.body`、`cast:c_02.speechStyle`、`edge:e_p_1.detail`。

**为什么不改落盘 id**：现有 id 已经进存档、进补丁 ops、进日志。换 id 体系是一次无谓的数据迁移；加一层引用解析成本几乎为零。

落点：[`lib/domain/main/entity_ref.dart`](../lib/domain/main/entity_ref.dart)，纯解析、零 IO。`EntityRef.parse` 校验「层前缀」与「该层允许的字段」，认错就抛可读错误（例如 `wb 没有这个字段：detail`）。

可寻址字段（与模型字段一一对应）：

| 层 | 字段 |
| --- | --- |
| `preset` | `name`、`description` |
| `wb` | `title`、`body`、`keys`、`alwaysOn` |
| `cast` | `name`、`summary`、`personality`、`speechStyle`、`exampleLines`、`isProtagonist` |
| `node` | `title`、`synopsis`、`tags` |
| `edge` | `from`、`to`、`kind`、`label`、`detail` |
| `pe` | `keyword`、`description`、`categoryId` |

**预设段（`preset:<id>.section:<sectionId>`）未实现**：预设只读，段级寻址等真的有调用场景再加。

---

## 5. 工具契约

### 5.1 命名

沿用现有 `域.动作`，补齐读写四件套：

| 域 | 读 | 写 |
| --- | --- | --- |
| `world` | `world.list` / `world.get` | `world.patch` |
| `cast` | `cast.list` / `cast.get` | `cast.patch` |
| `main` | `main.list_nodes` / `main.get_node` / `main.list_edges` / `main.get_edge` | `main.patch` |
| `plot` | `plot.list` / `plot.get` | `plot.select`（只勾选，不改库） |
| `preset` | `preset.list` / `preset.get` | `preset.patch`（调预设需谨慎，见 §8） |

现有 `world.list_entries` 等可保留为别名，或一次性收敛成 `world.list`（迁移成本低，调用点就在 `project_tools.dart`）。

### 5.2 入参与返回

入参用明确类型，不用裸 `Map<String, dynamic>`：

```text
world.get   { ref: "wb:wb_03", fields?: ["title","body"], maxChars?: 2000 }
world.list  { filter?: "alwaysOn" | "keyed", limit?: 50 }
```

返回统一信封，便于 Runner 与 UI 共同消费：

```json
{ "ok": true, "data": { ... }, "truncated": false, "tokenEstimate": 128 }
```

**阶段 1 采用的形式**：信封放在 `CreateToolResult.payload` 里，而不是给结果类加字段。原因是 `CreateToolResult` 已被十几个工具共用，加字段会在没有截断的工具上变成永远为假的死字段；放进 payload 则由真正需要截断的工具自己填。

已实装于 `world.read_entry` / `cast.read_member`：

```text
入参  { ref?: "wb:wb_03.body", id?: "wb_03", maxChars?: 4000 }
返回  { schemaVersion, ref, id, field?, value?, body?, truncated, tokenEstimate }
```

- 带字段的 ref 只回该字段（L3），不带字段回整条（L2）。
- `ref` 缺省时仍接受旧的 `id`，所以老调用点不会断。
- `maxChars` 截断时 `truncated: true`，模型据此知道可以再取下一段。

### 5.3 写操作统一用 ops

三个 `apply_*_patch.dart` 已经是按 id 的增量补丁，这套就是目标形态，**不需要重做**。阶段 1 已补两处真实缺口：

| 缺口 | 原状 | 现状 |
| --- | --- | --- |
| 连线 `detail` | 骨架 JSON 里有，任务提示没要求，applier 固定沿用旧值 | 提示词要求输出、`StageResultMapper` 解析、`ApplyMainGraphPatch` 写回；op 省略时沿用旧值 |
| 角色 `exampleLines` | applier 固定沿用旧值，新建为空 | `ApplyCastPatch` 接受 `exampleLines` 数组；op 省略时沿用旧值 |

补这两处时顺手统一了「省略即保留」的语义：凡是 op 里没给的字段，一律沿用原有值，不会因为模型只想改一个字段就把别的字段清空。

### 5.4 关于「用 MCP 协议」

**建议借鉴思路，不实现协议。**

MCP 解决的是「本进程 ↔ 外部独立进程」的工具互操作；本应用工具全在进程内，引入进程间协议等于自增一层无收益的故障面。

要照搬的是它的**形状**：固定工具名、固定 JSON Schema 入参、固定返回结构、读写分离、错误可枚举。这样未来真要把工具外置成 MCP server，改的是传输层，不是工具定义。

---

## 6. 渐进披露策略

### 6.1 创作侧（可以做完整工具循环）

创作是一次任务，允许几秒等待。目标流程：

```text
用户一句话
  → 注入：五块 L1 目录 + 任务规则
  → 模型自行决定：调 world.list / world.get / cast.get …
  → 模型产出 ops
  → 结构校验 + 预算校验
  → 半屏预览（逐条可勾选，见 §7 阶段 2）
  → 应用 / 放弃
```

这一步的收益最直接：**不再把整份世界书与骨架 JSON 塞进 user 消息**，长故事也不会因提示词过长而失焦。

### 6.2 聊天侧（不做真工具调用，已定）

聊天要实时响应，中途插工具调用会有明显卡顿。**已定不做**，走「命中注入」，三档：

1. **必进**：`alwaysOn` 条目 + 主角完整字段 + 主线摘要 + 当前站目标。
2. **命中进**：拿最近若干轮对话去匹配世界书 `keys`（**该机制已有字段但未实现**）与剧情元素关键词，命中才注入，并设条数上限。
3. **不进**：其余全量内容，只在创作侧按需取。

这样聊天侧的上下文从「与设定集总量成正比」变成「与当场对话相关度成正比」。

### 6.3 预算

线上定义一次输入预算 = `contextLength − maxTokens`。

- 组装顺序：任务规则 → L1 目录 → 必进项 → 命中项 → 对话历史 → 其余。
- 超预算时**从后往前丢**，优先牺牲旧对话与命中项，保住规则与 L1。
- 每次 `get` 都带 `maxChars`，超长返回 `truncated: true`，让模型知道可以再取下一段。

---

## 7. 落地阶段（已定顺序）

| 阶段 | 内容 | 前置 | 状态 |
| --- | --- | --- | --- |
| **0** | 协议层：消息支持 `tool_calls`，请求带 `tools`，响应解析 `tool_calls`；统一工具返回信封 | — | **协议层已完成** |
| **1** | `EntityRef` 引用解析；补 `edge.detail` 与 `exampleLines` 两个字段缺口 | 0 | **已完成** |
| **2** | 确认 UI：逐条 op 勾选 + 字段级 diff | 1 | **已完成** |
| **3** | 创作侧改成真循环：模型选工具 → 读 → 改 → 预览；退役 `wantsFullGraphRewrite` | 2 | 未开始 |
| **4** | 聊天侧命中注入：世界书 `keys` 与剧情元素关键词；三档取舍 | 1（不依赖 2、3） | 未开始 |
| **5** | 上下文预算裁剪，接入 `contextLength` | 4 | 未开始 |

**阶段 0 是唯一的硬前置**：没有它，后面全部是纸上设计。阶段 4 可与 2、3 并行，因为聊天侧不依赖工具循环。

**阶段 2 必须在 3 之前**：模型能精确出 op 之后，若确认抽屉仍只有「应用 / 跳过」，精确编辑就没有落点——用户只能整包接受或整包放弃。

### 7.1 阶段 0 实际落地

已完成，落在 foundation 两处：

- [`openai_chat_message.dart`](../lib/foundation/ai/openai_chat_message.dart)：新增 `OpenAiTool`（工具声明）与 `OpenAiToolCall`（模型请求的调用），`OpenAiChatMessage` 支持 `toolCalls` / `toolCallId` / `name`，`role: 'tool'` 可作为工具结果回传。
- [`openai_chat_client.dart`](../lib/foundation/ai/openai_chat_client.dart)：`complete(...)` 新增 `tools` / `toolChoice`（为空时不进请求体）；响应解析 `message.tool_calls`；修正「工具调用时 `content` 为空被判成『模型没有返回可用内容』」。

测试：`test/foundation/openai_chat_client_test.dart` 覆盖请求体开关、空 content 解析 tool_calls、tool 结果回传往返。

**与初版计划的偏差**：未在 `AiTextClient` 上加 `completeWithTools`。该抽象类有 12 处测试假实现用 `implements`，且阶段 0 没有任何调用方，加进去等于零收益的接口扰动。改为阶段 3 真实工具循环时随调用点一起加。

**「统一工具返回信封」顺延到阶段 1**：`CreateToolResult` 的 `truncated` / `tokenEstimate` 只有在读工具真正返回截断时才有意义，提前加字段属于无调用点的预留。

### 7.2 阶段 1 实际落地

| 落点 | 内容 |
| --- | --- |
| [`entity_ref.dart`](../lib/domain/main/entity_ref.dart)（新建） | 六层引用解析 + 每层允许字段校验 |
| [`project_tools.dart`](../lib/domain/ai/create/tools/project_tools.dart) | `world.read_entry` / `cast.read_member` 支持 `ref`（含字段级），返回 `truncated` / `tokenEstimate` |
| [`stage_result_mapper.dart`](../lib/domain/ai/stage_result_mapper.dart) | 解析 `detail`（顶层 edges 与站点 exits 两处） |
| [`apply_main_graph_patch.dart`](../lib/domain/main/apply_main_graph_patch.dart) | `upsert_edge` 写回 `detail`，省略时沿用 |
| [`apply_cast_patch.dart`](../lib/domain/main/apply_cast_patch.dart) | `upsert_member` 写回 `exampleLines`，省略时沿用 |
| [`create_prompt_profiles.dart`](../lib/domain/ai/create/create_prompt_profiles.dart) | 四个任务提示补上 `detail` / `exampleLines` 字段说明 |

测试：新增 `test/domain/entity_ref_test.dart`，并在补丁、骨架解析、工具注册表各自补用例。

**两处收窄**：

- 信封做成 payload 约定，没往 `CreateToolResult` 加字段（理由见 §5.2）。
- 预设段级寻址（`preset:<id>.section:<x>`）未做：预设只读，等真有调用场景再加。

### 7.3 阶段 2 实际落地

| 落点 | 内容 |
| --- | --- |
| [`patch_preview.dart`](../lib/domain/main/patch_preview.dart)（新建） | 逐条 op 单独应用并对比前后快照，产出 `PatchPreviewItem`（每条 op 的增/删/改实体与字段 before/after）；`applySelected` 只回放勾选的 op |
| [`patch_review_sheet.dart`](../lib/home/patch_review_sheet.dart)（新建） | 半屏确认抽屉：每行一个开关 + 字段级 diff（`原：…` / `改：…`），底部按钮实时显示选中条数 |
| [`create_assistant_panel.dart`](../lib/home/create_assistant_panel.dart) | `main.patch_graph` / `world.patch_propose` / `cast.patch_propose` 三条路径都走新抽屉；整图生成仍是整包替换 |

**做法**：不新增 applier 接口，而是让预览层对每条 op 调用一次现有 `apply`，再用「id → 字段快照」做 diff。这样：

- 归因精确（每个差异来自具体哪条 op），不用事后整体 diff。
- 只应用勾选项时按原顺序过滤 `ops` 再跑一次同一 applier，结果与预览一致。
- 删站顺带删掉的连线会作为「删除连线」出现在同一条 op 的差异里，用户能看见连带影响。

**默认勾选**：有实际改动且能单独应用的 op。空改动、引用坏掉的 op 默认不勾，并在行内标红说明。

**仍有限制**：若用户取消某条 op 而后续 op 依赖它（例如取消「新建站」却保留「连到该站」），回放时 applier 会抛错，面板把错误文本回填到对话里，不会写坏数据。

---

## 8. 已定决策

以下已拍板，实现以本节为准：

1. **聊天侧不做真工具调用**，走 §6.2 的命中注入三档。
2. **AI 只做提议，不直接落盘**。先输出改动意图与 ops，用户确认后才写回。
3. **确认 UI 先补**：逐条 op 勾选 + 字段级 diff，作为阶段 2 独立完成，先于创作侧真循环。
4. **预设只读**：不进写工具白名单，AI 只能读分段内容与顺序。
5. **起点是阶段 0 协议层**。

## 8b. 仍待定

1. **`world.list` 是否全量返回？**
   故事世界书可能上百条。倾向 `limit` 默认 50，超过时返回 `truncated: true` 并提示可按关键词过滤。

2. **旧工具名是否收敛？**
   `world.list_entries` 与 `world.list` 并存会让模型倾向选旧的。倾向一次改净。

3. **命中注入的匹配窗口有多长？**
   取最近几轮对话、是否计入上一拍的旁白，需要实测后再定。

---

## 9. 相关文档

- [PromptPipeline.md](./PromptPipeline.md) — 提示词如何拼装（本稿改的是「拼什么进去」）
- [CreateAgent.md](./CreateAgent.md) — 创作助手与工具注册表现状
- [Core.md](./Core.md) — 五块数据的领域定义
- [UX.md](./UX.md) — 创作助手入口与设置分区
- [MainBeat.md](./MainBeat.md) — 情节图区间与收敛约束
