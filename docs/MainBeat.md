# Main 节点 ↔ Beat Schema

主线可运行结构的契约：创作器节点编辑器与运行时（VN / 聊天）共用。实现可用 JSON / Dart class，字段名以本文件为准。

## 1. 关系总览

```text
Main
├── summary              主线概括（大纲，非逐句剧本）
├── startNodeId          开场节点
├── nodes[]              情节节点（画布上的块）
│     └── beatIds[]      有序；节点内默认按此顺序播
├── edges[]              节点间结构边（编辑器可见；运行时作默认出口）
└── beats[]              全主线 Beat 池（用 id 挂到节点）

运行指针：nodeId + beatId（+ 句内 lineIndex，可选）
```

| 层 | 粒度 | 谁编辑 | 运行时角色 |
| --- | --- | --- | --- |
| **Node** | 大情节站 / 里程碑（`synopsis` = 本站目标） | 创作时定骨架（画布） | 当前位置；合法区间的锚点；分组 Beats |
| **Edge** | 节点 → 节点（含分支） | 创作时定骨架 | **封闭的下一站集合**；区间收敛出口；无选项时的默认流向 |
| **Beat** | 可播放最小单元 | 创作预写 **或** 游玩时区间 AI 生成 | 真正演出：场景、对白、选项 |

产品语义见 [Core.md](./Core.md)「脉络骨架 + 区间内 AI」。本文管字段与推进。

**硬规则**

1. 一句对白 ≠ 一个 Node；对白落在 Beat 的 `lines`。
2. 分支优先：Beat 上的 `choices` 决定跳转；无 choices 时才走「下一 Beat → 节点默认 Edge / 收敛出口」。
3. `choices.target` 可以指向 Beat 或 Node（见 Transition）；禁止只写散文式「后果摘要」而无目标（摘要可放 `note`，不能代替跳转）。
4. **运行时不得增删 `nodes` / `edges`**；区间 AI 只能生成挂在当前节点下的 Beats，以及指向**已有** `nodeId` / `end` 的 Transition。
5. Side 支线日后可复用同一 Beat / Transition 形状；本文只定 Main。

---

## 2. 类型定义

### 2.1 Main

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `summary` | `string` | 是 | 主线概括 |
| `startNodeId` | `Id` | 是 | 必须存在于 `nodes` |
| `nodes` | `Node[]` | 是 | 至少 1 个 |
| `edges` | `Edge[]` | 是 | 可空数组；线性故事也建议显式连线 |
| `beats` | `Beat[]` | 是 | 可空；无 Beat 的节点不可完整体验 |

`Id`：项目内稳定字符串（建议 UUID 或 `n_xxx` / `b_xxx`），重命名标题不改 Id。

### 2.2 Node（情节节点）

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `id` | `Id` | 是 |  |
| `title` | `string` | 是 | 画布上显示的短标题 |
| `synopsis` | `string` | 否 | 本节点目标/摘要（给作者与 AI，玩家可不直接看到） |
| `beatIds` | `Id[]` | 是 | 有序；必须都在 `Main.beats` 且 `beat.nodeId == this.id` |
| `layout` | `NodeLayout` | 否 | **仅编辑器**：画布坐标；不参与运行逻辑 |
| `tags` | `string[]` | 否 | 含站种类：`opening` / `scene` / `turning` / `ending`（画布标题栏色 + 种类芯片；色见 `StoryNodeKindStyle`；`ending` 仍参与校验/运行） |

```text
NodeLayout { x: number, y: number }
```

- 删除节点：同时删除其 `beatIds` 对应 Beats，并删除所有相关 `edges`。
- 允许 `beatIds` 为空（骨架占位）：表示「本站内容交给游玩时区间 AI」。**开玩前校验不再把「空 beatIds」一律当错误**；无出边时进入**开放区间**（自由续写），有出边时 `synopsis` 建议非空（收敛锚点）。
- `nodes` 为空为警告（非错误）；游玩注入临时开场站，不写回包。
- 若故事关闭区间 AI 且节点仍无 Beat，则导出/开玩报错（纯静态包模式）。

### 2.3 Edge（节点边）

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `id` | `Id` | 是 |  |
| `from` | `Id` | 是 | 源节点 |
| `to` | `Id` | 是 | 目标节点 |
| `kind` | `"default" \| "branch"` | 是 | 见下 |
| `label` | `string` | 否 | 画布出线插头按钮标题；也可作保底选项文案 |
| `detail` | `string` | 否 | 这条路的详细说明（作者笔记 / 给 AI 的走向提示）；可点插头编辑，也可用 AI 根据标题+草稿展开 |
| `priority` | `number` | 否 | 同 from 多条 `default` 时取最小者；默认 `0` |

**`kind` 约定**

- `default`：该节点 Beats 播完且当前 Beat **无 choices** 时的默认出口。同一 `from` 建议仅一条 `default`（多条时用 `priority`）。
- `branch`：结构示意 / 文档用，或将来条件边；**MVP 运行时可不自动走 `branch`**，玩家可见分支以 Beat `choices` 为准。画布仍可画 `branch` 边帮助作者看清骨架。

汇合：多条边指向同一 `to` 即可，无需特殊汇合节点类型（MVP 不做合并算子）。

### 2.4 Beat（可播放单元）

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `id` | `Id` | 是 |  |
| `nodeId` | `Id` | 是 | 所属节点；须与某节点 `beatIds` 互洽 |
| `scene` | `Scene` | 是 | 本拍场景；可继承策略见 §3 |
| `appearances` | `Appearance[]` | 是 | 可空；本拍出场立绘 |
| `lines` | `DialogueLine[]` | 是 | 可空；空 Beat 仅作跳板时需有 `choices` 或依赖默认推进 |
| `choices` | `Choice[]` | 是 | 可空；空则播完 `lines` 后走默认推进（§3） |
| `note` | `string` | 否 | 作者/AI 备注，不进入玩家必读 |
| `tags` | `string[]` | 否 |  |

### 2.5 Scene / Appearance / DialogueLine / Choice / Transition

```text
Scene {
  locationText?: string          // 地点说明
  backgroundAssetId?: AssetId    // 背景图；生图或导入后的资源 id
}

Appearance {
  characterId: Id                // Cast
  spriteAssetId?: AssetId        // 立绘；可空则仅聊天头像或占位
  expression?: string            // 表情键；MVP 可当自由字符串
  slot?: "left" | "center" | "right"  // VN 站位；可选
}

DialogueLine {
  id: Id
  speakerId?: Id                 // 空 = 旁白/系统
  text: string
  kind: "speech" | "narration"   // 默认 speech；无 speaker 时建议 narration
}

Choice {
  id: Id
  text: string                   // 选项按钮 / 聊天气泡选项
  target: Transition
}

Transition {
  type: "beat" | "node" | "end"
  beatId?: Id                    // type=beat 时必填
  nodeId?: Id                    // type=node 时必填；进入该节点 beatIds[0]
}
```

**Transition 语义**

| `type` | 行为 |
| --- | --- |
| `beat` | 跳到指定 Beat（可跨节点；若跨节点须更新当前 `nodeId` 为该 Beat 的 `nodeId`） |
| `node` | 跳到节点，从该节点 `beatIds[0]` 开始；空 `beatIds` 则非法 |
| `end` | 主线结束（通关/段落结束） |

---

## 3. 运行时推进规则（双模式共用）

状态：`{ nodeId, beatId, lineIndex, phase }`（`lineIndex` / `phase` 为 VN 句内进度，现已写入存档以便续玩与回退）。开启区间 AI 时，另有本局会话态（见 §5）。

### 3.1 静态推进（预写 Beat）

1. **进入节点**：若未指定 Beat，且 `beatIds` 非空，取 `node.beatIds[0]`。
2. **播放 Beat**：展示 `scene`、`appearances`；按序展示 `lines`（VN 一句句点；聊天可作连续气泡）。
3. **Beat 结束时**  
   - 若 `choices.length > 0`：等待玩家选择 → 执行 `target`。  
   - 否则若存在下一拍：`beatIds` 中当前下标 +1 → 该 Beat。  
   - 否则若存在从当前节点出发、`kind == default` 的 Edge：取 `priority` 最小者 → `Transition{ type: node, nodeId: edge.to }`。  
   - 否则 → `needsBridge`（开放区间或等待分支；显式 `end` choice / `ending` 站才结束）。
4. **场景继承（MVP 建议）**：若某 Beat 的 `backgroundAssetId` 为空，沿用本节点内上一 Beat 的背景；跨节点不自动继承（避免错景）。立绘不自动继承，缺省即清场或仅保留 `appearances` 明示者（实现二选一，**建议：不自动继承立绘**）。

### 3.2 区间 AI 推进（当前实现）

适用于 **视觉小说** 游玩：进入节点后 `beatIds` 为空，或预写拍播完仍需发挥。落点：[`BridgeSession`](../lib/domain/runtime/bridge_session.dart)、[`BridgeGenerateAction`](../lib/domain/ai/bridge_generate_action.dart)、[`MainRuntime`](../lib/domain/runtime/main_runtime.dart)（`PlayPhase.needsBridge`）、[`PlaySessionPage`](../lib/play/play_session_page.dart)（仅 VN 模式）。

1. **开区间**：绑定 `nodeId`；上下文 = Preset + Background/Cast 摘要 + 本节点 `title`/`synopsis` + 出边列表（可空）+ 区间摘要。进站若已是 `needsBridge`，游玩页自动生成。游玩入口 [`ensurePlayableMain`](../lib/domain/project/project_factory.dart) 会去掉无出边站上「仅结束」的旧占位拍（不写回包），避免空白故事只能点结束。
2. **生成一拍**：模型输出 Beat JSON；非法 `nodeId` 的 choice 丢弃；格式失败最多重试 1 次。每拍 `choices` **最多 3**（prompt + 解析截断）。每拍 `lines` 的**最少句数**由设置 → AI → **视觉小说演出 → 每段最少句数**（[`AiSettings.minBridgeLines`](../lib/domain/settings/ai_settings.dart)，默认 **10**，范围 1–10）决定。`type: beat` + `beatId: __stay__` 表示继续本区间（再选 → `needsBridge`）。
3. **何时带选项**：  
   - **出站 / 触顶收敛拍**：必须有 choices（合法 `node` / `end`）。  
   - **站内过程拍**（含开放站续写）：默认可空 choices，玩家**点屏幕**播完后接下一段；出现站内选项的频率由设置 **站内选项**（[`InStationChoiceFrequency`](../lib/domain/settings/ai_settings.dart)，默认「很少」）调节。空 choices **不再**自动补「继续」。
4. **剧情树预写**（[`PlaySessionPage`](../lib/play/play_session_page.dart)）：情节图是骨架；游玩时 AI 生长的拍 + [`branchEdges`](../lib/domain/runtime/bridge_session.dart) 构成**本局剧情树**，完整进存档。  
   - **最新拍无 choices**：线性队列目标 **2**。  
   - **最新拍有 choices**：[`BridgeBranchPrefetchAction`](../lib/domain/ai/bridge_branch_prefetch_action.dart) 一次批写至多 3 路各 1 拍（每路亦至少 `minBridgeLines` 句）；`end` 不预写。  
   - **点选**：查边复用；其它分支保留。  
   - **重新生成**：[`pruneSubtree`](../lib/domain/runtime/bridge_session.dart) 剪子树，兄弟保留。  
   - 生成中只在标题栏转圈。
5. **有出边**：  
   - `maxBridgeBeats` 默认 **10**；触顶禁止 stay，必须合法 `node`/`end`；接近触顶时 prompt 引导自然铺垫换站。  
   - UI 保底「前往：{下一站}」；`fallbackChoices` 亦 ≤3。
6. **无出边（开放区间）**：不触顶强制收敛；过程拍默认空 choices（点屏续写）；频率允许时才可给「继续 / 告一段落」；`fallbackChoices` = 「继续」+「告一段落」。
7. **入下一站**：合法 `node` Transition 后更新当前 `nodeId` / `turnCount` / `summary`；**保留**本局全部 `generatedBeats` 与 `branchEdges`，会话写入存档附件，**不写回**故事包。
8. **范围**：本节状态机只服务 VN。聊天见 §3.3。

### 3.3 双模式

开玩时的 [`PlayViewMode`](../lib/domain/runtime/play_view_mode.dart) 锁定，局内不切换。

| 模式 | 推进 | 存档 |
| --- | --- | --- |
| 视觉小说 | §3.1–3.2 指针 + 区间 AI | `pointer` + 可选 `bridge` |
| 聊天 | 酒馆交替：[`TavernChatGenerateAction`](../lib/domain/chat/tavern_chat_generate_action.dart) 一轮助手；用户输入或 [`TavernReplyChoiceAction`](../lib/domain/chat/tavern_reply_choice_action.dart) 选项；UI [`PlayChatView`](../lib/play/play_chat_view.dart) | 独立 `slotId`：`mode` + `chat[]` + `replyChoices[]`；故事详情开玩新建槽；存档页按槽续玩 |

---

## 4. 校验（导出 / 开玩前）

| 级别 | 规则 |
| --- | --- |
| 错误 | `startNodeId` 不存在；`beatIds` 与 `nodeId` 不一致；悬空 Id；预写 `choices` 的 Transition 目标不存在 |
| 错误 | 静态包模式（关闭区间 AI）下节点 `beatIds` 为空 |
| 警告 | `nodes` 为空（游玩注入临时开场）；起点 `beatIds` 为空；孤立节点；`branch` 无 Choice 指向；`synopsis` 为空；无出边的非 ending 站（开放区间） |

---

## 5. 存档（最小）

```text
MainSavePointer {
  nodeId: Id
  beatId: Id            // 预写拍；若在区间会话中可为 session beat id
  lineIndex?: number    // VN 当前句；旧档可缺省 → 从该拍首句恢复
  phase?: string        // lines | choices | needsBridge | ended
  // flags?: map         // 日后变量；MVP 可省略
}

// 开启区间 AI 时附加（本局，不进故事包；可作导出导入的剧情树载体）：
BridgeSession {
  nodeId: Id               // 当前开放区间所在站
  generatedBeats: Beat[]   // 本局全部生成拍（全部分支累积）
  branchEdges?: {          // 决策脉络；旧档可缺省 → []
    fromBeatId: Id
    choiceId: Id
    toBeatId: Id
  }[]
  turnCount: number        // 当前站已生成拍数，用于收敛触顶
  summary?: string         // 当前站压缩摘要，供下一跳上下文
}

// VN 回退时间线（与 pointer 同槽保存）：
history: MainSavePointer[]   // 记录过的每一句 / 待生成位置，旧 → 新
historyCursor: number        // 当前所在下标；-1 表示旧档未记录
```

回退：`pointer` 始终是**当前查看位置**，`history` 末尾是最新进度。时间线按「句」记录——同一句的
`lines` / `choices` / `needsBridge` 只更新该条，不算新的一步。后退 / 前进移动 `historyCursor` 并
`MainRuntime.restore`；快进按顺序重放已记录位置，到末尾停；已在末尾时「前进」等同继续推进。
回退改选会截断光标之后的**足迹**（`history`），但 **`generatedBeats` / `branchEdges` 不随改选抹掉**——其它分支可再次进入；有边则复用已有拍。

故事包仍以骨架（+ 可选预写 Beat）为准；存档存指针 + 本局区间会话，不要求把 AI 发挥写回 `project.json`（作者可另做「固化本场」创作动作）。

---

## 6. 与编辑器的对应

| UI | 数据 |
| --- | --- |
| 画布上的块 | `Node` + `layout` |
| 块之间的线 | `Edge` |
| 点进节点（本阶段浮层） | 改 `title` / `synopsis` / 出边；预写 `Beat` 表单未做，过程戏靠区间 AI |
| Beat 内选项 | `Choice`；若选项跳到其他节点，可同时建议创作器维护/提示对应 `Edge`（可自动补 `branch` 边，MVP 可选） |
| 开场 | `startNodeId` |
| 撤销 / 重做 | 编辑会话内整图快照（不改 schema） |

移动端：改的是同一 schema；交互只影响如何改 `nodes/edges/layout`，不改变运行语义。

### 6.1 AI 读写用的骨架 JSON

故事包落盘仍是完整 `Main`（含 `beats`）。给模型生成走向、或把当前图塞进提示词时，用 [`MainGraphDocument`](../lib/domain/main/main_graph_document.dart)：

| 字段 | 说明 |
| --- | --- |
| `format` | 固定 `anoworld.main_graph.skeleton` |
| `version` | `1` |
| `summary` / `startNodeId` | 同 Main |
| `nodes[]` | `id` / `title` / 可选 `synopsis` / `tags` / 可选 `layout`；**无** `beatIds` |
| `edges[]` | 与 Main 边 JSON 相同 |
| （无 `beats`） | 解码后 `beats` 为空；站上 `beatIds` 默认 `[]` |

`encode` / `decode` 走完整 Main；`encodeSkeleton` / `decodeSkeleton`（及 `*Json`）走上表。`decodeSkeleton` 若见到完整 Main map（含 `beats`）则按完整解码。

---

## 7. 最小示例（线性两节点）

```text
Main.summary = "少年离家，雨夜投宿。"
startNodeId = n1
nodes = [
  { id: n1, title: "城门", synopsis: "离开", beatIds: [b1], layout: {x:0,y:0} },
  { id: n2, title: "客栈", synopsis: "投宿", beatIds: [b2], layout: {x:200,y:0} },
]
edges = [
  { id: e1, from: n1, to: n2, kind: "default" },
]
beats = [
  {
    id: b1, nodeId: n1,
    scene: { locationText: "城门", backgroundAssetId: "bg_gate" },
    appearances: [{ characterId: "c_hero", slot: "center" }],
    lines: [
      { id: l1, speakerId: "c_hero", text: "该走了。", kind: "speech" },
    ],
    choices: [],
  },
  {
    id: b2, nodeId: n2,
    scene: { locationText: "客栈", backgroundAssetId: "bg_inn" },
    appearances: [{ characterId: "c_hero", slot: "left" }, { characterId: "c_keeper", slot: "right" }],
    lines: [
      { id: l2, speakerId: "c_keeper", text: "留宿？", kind: "speech" },
    ],
    choices: [
      { id: ch1, text: "住下", target: { type: "end" } },
      { id: ch2, text: "再看看", target: { type: "beat", beatId: "b2" } },
    ],
  },
]
```

`b1` 无选项 → 无下一 Beat → 走 `default` Edge → `n2` 的 `b2`。
