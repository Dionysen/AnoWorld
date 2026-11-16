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
| **Node** | 情节单元 / 场景块 | 主线节点画布 | 图上的位置；分组 Beats；默认出口 |
| **Edge** | 节点 → 节点 | 画布连线 | 无选项时的默认流向；汇合/分支骨架 |
| **Beat** | 可播放最小单元 | 点进节点后的详情 | 真正演出：场景、对白、选项 |

**硬规则**

1. 一句对白 ≠ 一个 Node；对白落在 Beat 的 `lines`。
2. 分支优先：Beat 上的 `choices` 决定跳转；无 choices 时才走「下一 Beat → 节点默认 Edge」。
3. `choices.target` 可以指向 Beat 或 Node（见 Transition）；禁止只写散文式「后果摘要」而无目标（摘要可放 `note`，不能代替跳转）。
4. Side 支线日后可复用同一 Beat / Transition 形状；本文只定 Main。

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
| `tags` | `string[]` | 否 | 可选标签 |

```text
NodeLayout { x: number, y: number }
```

- 删除节点：同时删除其 `beatIds` 对应 Beats，并删除所有相关 `edges`。
- 允许 `beatIds` 为空（占位节点）；运行若落到空节点，视为内容错误或自动沿默认 Edge 跳出（实现选一种并固定；**建议 MVP：视为错误，创作器校验拦截导出**）。

### 2.3 Edge（节点边）

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `id` | `Id` | 是 |  |
| `from` | `Id` | 是 | 源节点 |
| `to` | `Id` | 是 | 目标节点 |
| `kind` | `"default" \| "branch"` | 是 | 见下 |
| `label` | `string` | 否 | 画布上分支标注；可不等于玩家选项文案 |
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

状态：`{ nodeId, beatId, lineIndex }`（`lineIndex` 仅 UI 用，存档可只存前两者）。

1. **进入节点**：若未指定 Beat，取 `node.beatIds[0]`。
2. **播放 Beat**：展示 `scene`、`appearances`；按序展示 `lines`（VN 一句句点；聊天可作连续气泡）。
3. **Beat 结束时**  
   - 若 `choices.length > 0`：等待玩家选择 → 执行 `target`。  
   - 否则若存在下一拍：`beatIds` 中当前下标 +1 → 该 Beat。  
   - 否则若存在从当前节点出发、`kind == default` 的 Edge：取 `priority` 最小者 → `Transition{ type: node, nodeId: edge.to }`。  
   - 否则 → `end`（或创作器校验要求必须有出口）。
4. **场景继承（MVP 建议）**：若某 Beat 的 `backgroundAssetId` 为空，沿用本节点内上一 Beat 的背景；跨节点不自动继承（避免错景）。立绘不自动继承，缺省即清场或仅保留 `appearances` 明示者（实现二选一，**建议：不自动继承立绘**）。

聊天模式：同一套指针与 `choices`；续写若开启，仍绑定当前 `nodeId`（及允许的设定注入），不得暗中写另一套剧情树。续写结果若要固化，应写回为新 Beat/Line（创作动作），不在本文展开。

---

## 4. 校验（导出 / 开玩前）

| 级别 | 规则 |
| --- | --- |
| 错误 | `startNodeId` 不存在；`beatIds` 与 `nodeId` 不一致；悬空 Id；`choices` 的 Transition 目标不存在；空 `beatIds` 仍被 start 或唯一 default 指入且无法出口 |
| 错误 | 某节点播放路径结束时既无下一 Beat、又无 `default` Edge、当前 Beat 也无 `choices`/`end` |
| 警告 | 孤立节点（从 start 不可达）；`branch` 边无任何 Choice 指向对应 `to`；节点无 Beat |

---

## 5. 存档（最小）

```text
MainSavePointer {
  nodeId: Id
  beatId: Id
  // lineIndex?: number
  // flags?: map  // 日后变量；MVP 可省略
}
```

资源与文本以项目内容为准；存档只存指针（及日后变量），不复制 Beat 正文。

---

## 6. 与编辑器的对应

| UI | 数据 |
| --- | --- |
| 画布上的块 | `Node` + `layout` |
| 块之间的线 | `Edge` |
| 点进节点后的列表 | 该节点 `beatIds` → `Beat` |
| Beat 内选项 | `Choice`；若选项跳到其他节点，可同时建议创作器维护/提示对应 `Edge`（可自动补 `branch` 边，MVP 可选） |
| 开场 | `startNodeId` |

移动端：改的是同一 schema；交互只影响如何改 `nodes/edges/layout`，不改变运行语义。

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
