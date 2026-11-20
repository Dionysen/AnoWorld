# AnoWorld 内容核心模型

创作器产出、运行时消费的同一套内容分层。聊天与 VN **共用** WorldBook / Cast /（可选）Main 素材；呈现与推进状态分开。

## 分层总览

```text
Project（故事包）
├── worldBook      世界观 / 设定条目（语义对齐酒馆世界书）
├── Cast           角色
├── Main           主线概括 → 大节点与分支（画布）→（节点内）Beats
├── Side           支线定式 + 定式下的填槽发挥
├── plotElements   勾选的全局剧情元素 id（keyword+描述在全局库）
└── Beats/Scenes   可运行最小单元（双模式共用；可创作预写，也可运行时由 AI 填）

App 全局（设置，与酒馆同类）
├── AiPreset       酒馆兼容预设：采样 + 提示词管理
├── Persona        玩家身份（名字、描述、可选绑定），供 {{user}} / persona 段
└── PlotElements   剧情元素全局库（种子 + 覆盖/删除 + 自建 + 分类 + 元素包；玩法页管理）

依赖方向：**全局 AiPreset + Persona** 约束「怎么组请求、怎么采样、玩家是谁」；WorldBook / Cast 支撑「写什么」（世界书 + **多角色**）；Main 的**节点与边**管「故事能走到哪」；Beat 才是屏幕上逐步演出的东西。

相对酒馆，AnoWorld **多加**：**情节走向（Main 图）**与更细的 **Cast（含配角）**；其余提示词、预设、玩家身份、**宏与变量**尽量与 ST/NativeTavern **同一套语义**。

**产品形态（权威）**：开玩选定 [`PlayViewMode`](../lib/domain/runtime/play_view_mode.dart) 并锁定（存档字段 `mode`）。**聊天**对齐酒馆：严格 AI/用户交替 + 回复选项（[`TavernChatGenerateAction`](../lib/domain/chat/tavern_chat_generate_action.dart) / [`TavernReplyChoiceAction`](../lib/domain/chat/tavern_reply_choice_action.dart) + [`PlayChatView`](../lib/play/play_chat_view.dart)）；对话写入存档 `chat`；Main 节点仅可选注入提示词。**视觉小说**走 Main 指针 + 区间 AI（[`MainRuntime`](../lib/domain/runtime/main_runtime.dart) + [`PlaySessionPage`](../lib/play/play_session_page.dart) 舞台：全屏背景、底部对白、点屏推进、中央选项）。详见 [MainBeat.md](./MainBeat.md)、[UX.md](./UX.md)、[Style.md](./Style.md)。

**Main ↔ Beat 字段与推进规则**：见 [MainBeat.md](./MainBeat.md)（权威 schema）。

## 全局 AiPreset（玩法 · 酒馆预设）

- **拼装流水线（权威）**：每次文本 AI 调用前的段顺序、锚点、任务层与裁剪，见 [PromptPipeline.md](./PromptPipeline.md)。
- **是什么**：与 SillyTavern **同名同构**的 AI 预设——导入/导出 ST 预设 JSON（`temperature`、`prompts`、`prompt_order` 等）。实现对照 NativeTavern：`AIPreset`、`GenerationPreset`、`PromptManagerConfig`。
- **作用域**：**全局**，所有故事与所有文本 AI 动作共用当前选用的一套；故事包内**不再**存放预设。
- **与 WorldBook 的分工**：WorldBook = 本故事世界书式事实；AiPreset = 跨故事通用指令与采样。二者分属不同设置/编辑入口。
- **应用行为**（对齐 NT）：「应用」覆盖文本通道采样参数，并写入实时提示词配置；可从当前连接 + 提示词「另存为」自定义预设。
- **新增与管理**：新建预设从出厂采样 + 默认提示词段开始；保存当前设置把实时采样与提示词存成自定义预设；内置预设只能应用，不能改名或删除。提示词段的「恢复默认顺序」只把内置段排回出厂次序，自定义段留在原位置。
- **对 AnoWorld 的附加约束**：创作/游玩请求在 ST 拼装之后仍追加**任务说明与 JSON schema**；合法下一站、结局出口等收敛规则不被预设绕过。
- **拼装映射（渐进）**：

| ST 提示词段 | AnoWorld 来源 |
| --- | --- |
| `persona` | 设置里**当前 Persona**（与 ST 相同字段语义） |
| `worldInfo*` | `WorldBook` 条目（故事内世界书） |
| `charDescription` 等 | **焦点角色** = `Cast` 里勾选 **主角** 的那一名；配角以完整 Cast 注入扩展段或自定义段 |
| `chatHistory` | 游玩区间会话（非无限聊） |
| `main` / `jailbreak` / custom | 预设文件内文案 |

**宏与变量**：提示词与条目正文中的 `{{user}}`、`{{char}}`、`{{description}}`、时间/随机，以及 ST **Macros 2.0** 变量语法，在发送前按酒馆规则展开（实现 port 同级 NativeTavern 的 `MacroService` / 变量层）。`{{char}}` 等**角色宏**只绑定 **勾选主角** 的 `CastMember`（[`isProtagonist`](../lib/domain/models/cast.dart)）；未勾选则无焦点、宏不胡填别名。配角通过各成员字段与世界书进上下文。

**任务层**：在上述 ST 拼装完成之后，应用层再追加 AnoWorld 专用段（当前站 `synopsis`、合法下一站 JSON、schema），不由宏替代。

- **故事包 schema v3**：在 v2 基础上增加 `plotElements.selectedIds`（勾选全局剧情元素 id；未知 id 展示时跳过）与 `plotElements.appliedPackIds`（已打开的元素包 id；缺省视为空，用于判断某条元素是否由包带入）。v2：已移除 `Project.presets` / `activePresetId`；v1 包读入时忽略上述字段。 `ProjectMeta.coverPath` 可选，相对 `assets/`（如 `cover.jpg`）；详情页可换封面。角色卡 system/post-history **不写进故事包**（导入页仅提示，请在玩法 → 预设调整）。
- **剧情元素（全局库）**：[`PlotElement`](../lib/domain/models/plot_element.dart) = `keyword` + `description`（≤300 字）+ `categoryId`（空 = 未分类）；出厂种子 [`BuiltInPlotElements`](../lib/domain/settings/built_in_plot_elements.dart)，出厂分类 `BuiltInPlotElementCategories`（日常 / 情感 / 冲突 / 危机 / 悬疑 / 心理 / 灵异，可改名不可删）；用户改删存 [`PlotElementCatalog`](../lib/domain/settings/plot_element_catalog.dart)（prefs `anoworld.plot_elements.v1`：overrides / deletedBuiltInIds / custom / customCategories / categoryRenames / packs）。[`PlotElementPack`](../lib/domain/models/plot_element_pack.dart) = `name` + `elementIds`，只引用全局条目 id；应用包即把 `elementIds` 一次性并入/移出故事勾选（[`PlotElementSelection.withIds`](../lib/domain/models/plot_element.dart)），不拷贝全文；删条目时同步从各包摘掉该 id。故事勾选另存 `appliedPackIds`（已打开的包），据此区分「这条是包带进来的」与「用户单独勾的」：包之间不互斥，取消一个包只移除不再被其他已打开包覆盖的 id；应用/取消前若与单独勾选或其他已打开包重叠，由 [`PlotElementCatalog.planPackApply`](../lib/domain/settings/plot_element_catalog.dart) / `planPackRemove` 给出受影响的条目，页面弹确认后再落盘。分类按 id 引用，改名不触碰条目；故事只存勾选 id。创作助手（情节图目标）也能查库、勾选或新增条目（[`ApplyPlotPatch`](../lib/domain/main/apply_plot_patch.dart)）：新增写进同一份全局库，故事包里仍只存 id。
- **仍不做**：ST 正则链、插件；预设不得增删 Main 节点。

## WorldBook（世界书）

- **是什么**：最宏大也最基础的设定——时代、势力、规则、人物关系、不可轻易打破的事实。
- **形态**：故事内 **设定条目**列表（[`WorldBookEntry`](../lib/domain/models/world_book.dart)），语义对齐酒馆世界书，按故事打包而非全库 lore。故事包 JSON 字段 `worldBook`（读入兼容旧键 `background`）。
  - `alwaysOn`：常驻注入（基调 / 硬规则）。
  - `keys`：明文关键词；播放时按近文命中注入，未填则退化为标题匹配（[`PlayContextSelector`](../lib/domain/ai/play_context_selector.dart)，见 [AgentTools.md](./AgentTools.md) §6.2）。
  - 正文须自洽；标题 / 关键词不进模型。
- **借鉴 ST、明确不做**：条目化 + 常驻/按需 + 预算思路可借鉴；**不做**正则 Key、多层递归、插入深度/Outlet、概率互斥组、Sticky/Cooldown、全局/人格/聊天多层 lore 叠加、扩展脚本。
- **兼容**：旧包 `sections[]` 读入时升为 `alwaysOn` 条目；写出用 `entries[]`。

## Persona（玩家身份 · 设置）

- **是什么**：与酒馆 **User Persona** 相同——全局可建多套，选用一套作为当前玩家；提供显示名与描述，写入提示词 `persona` 段，并驱动 `{{user}}` / `{{user_description}}` / `{{persona}}` 等宏（数据形状对照 NativeTavern `Persona`）。
- **作用域**：默认全局；与 ST 类似的「绑定某角色/某对话」可分期对齐，MVP 至少支持**选一个当前 Persona**。
- **与 Cast 分工**：Persona = **玩家**是谁；Cast = **故事里有哪些角色**（含配角）。玩家名字出现在对白里用 Persona，不出现在 Cast 里（除非作者故意做自设角色条目）。

## Cast（角色）

- 姓名、设定摘要、性格、对白风格、示例对白、立绘/头像资源引用等；**支持多名角色（主角 + 配角）**，比重酒馆的「单卡聊天」更细。其中 **至多一名** 可勾 **主角**（驱动 `{{char}}`）；导入角色卡时第一张默认勾选。
- 来源：手建，或从 ST 角色卡**选择性摘取**字段后映射至此（及必要的 WorldBook 条目）；解析见 [`StCharacterCardParser`](../lib/domain/card_import/st_character_card_parser.dart)，映射见 [`StCardProjectMapper`](../lib/domain/card_import/st_card_project_mapper.dart)。导入时 [`RichTextSanitizer`](../lib/foundation/text/rich_text_sanitizer.dart) 去 HTML、保留 Markdown；可选手动「清理格式」。
- 立绘等图片：优先走**生图通道**配置的供应商（与文本/LLM 供应商列表分离，对齐 NativeTavern `ImageGenProvider`）；同时支持用户本地导入；运行时只认资源引用。
- 角色是素材与演出主体，不是 ST 运行时人格容器；无插件、无正则人格脚本。

## Main（主线）——可选脉络 + 区间内 AI

有大纲时对标 Gal / SLG：**大走向可定**，玩家走进分支；**站间过程由 AI 实时生成**并收敛。无大纲时仍可玩：单站开放区间，AI 按设定与角色续写。

空白故事（[`ProjectFactory.createBlank`](../lib/domain/project/project_factory.dart)）只有一站「开场」、`beatIds` 为空；开玩即 `needsBridge`。包内若 `nodes` 为空，游玩用 [`ensurePlayableMain`](../lib/domain/project/project_factory.dart) 注入临时开场（不写回包）。

### 两层分工

| 层 | 何时定 | 是什么 | 不是什么 |
| --- | --- | --- | --- |
| **脉络骨架（可选）** | **创作时**生成/编辑并固化进故事包 | `summary`、大节点（标题 + 本站目标 `synopsis`）、`edges`（顺序 / 分支 / 汇合）、通往各结局的出口 | 不是逐句剧本；不是开玩的硬门槛 |
| **区间发挥** | **游玩时**实时生成 | 若干 Beat：场景感、对白、过程选项；受 AiPreset + WorldBook + Cast 约束；**有出边则收敛，无出边则开放 stay** | 有骨架时不得发明不存在的下一站 id |

```text
有出边：  进入节点 A ──AI 区间 Beats──▶ 收敛到 edge 指向的 B / 结局
无出边：  进入开场 ──AI 开放续写──▶ stay「继续」循环（可 end 告一段落）
```

### 骨架字段（创作）

- **主线概括 `summary`**：整段故事的目标、冲突、可能结局方向（给作者与 AI 用，不是逐句剧本）。
- **节点（大情节单元）**：里程碑式「这一步故事要发生什么」；`synopsis` = 本站必须达成或抵达的剧情目标（运行时 AI 的收敛锚点）。节点之间的流向（顺序、分支、汇合）在**主线节点编辑器**表达。
- **粒度**：节点是情节级大站，不是每一句对白一个节点；句段级内容落在 Beat。
- **分支与结局**：用 `edges` / 节点出口表达多路线；玩家选择最终应对齐到某条合法边或 `end`，从而可能达成不同结局。
- **编辑 UX**：故事内先进入创作截面（设定 / 角色 / 情节），情节再进全端节点画布；改 AI 气质在 **玩法 → 预设**；底栏「画布 / 卡片」切换聚焦相机；走向全览用节点 PNG 缩略图（`assets/graph_nodes/{nodeId}.png`，创建/改文案后重渲；拖动改布局只即时改坐标并防抖落盘，不重渲缩略图）；结构编辑走通用 [`UndoStack`](../lib/foundation/history/undo_stack.dart)（整图快照，拖节点在松手时合并为一步）。验收见 [UX.md](./UX.md)。
- **序列化**：故事包内完整 `Main` 仍用 [`MainStory.toJson`](../lib/domain/models/main_story.dart)；供 AI 生成 / 作提示词的紧凑图用 [`MainGraphDocument`](../lib/domain/main/main_graph_document.dart)（`anoworld.main_graph.skeleton` v1：`summary` + 站 + 边，可无 `beats` / `layout`）。反序列化可吃 skeleton 或完整 Main map。
- **预写 Beat（可选）**：作者或创作 AI 可预写某节点内的开场钩子；**默认允许节点在创作结束时 Beat 仍为空**，交给游玩时 AI 填（校验规则见 MainBeat）。

### 区间 AI（游玩）

- 玩家处在某主节点的「发挥区间」：本站 `synopsis`（可空）、出边（可无）、WorldBook / Cast、全局 AiPreset、近期游玩摘要。
- **VN**：AI 实时生成对白与过程选项（[`MainRuntime`](../lib/domain/runtime/main_runtime.dart) + [`BridgeGenerateAction`](../lib/domain/ai/bridge_generate_action.dart)）。
- **有出边**：须存在收敛通路；玩家点导向某站的选项后跳到 `edge.to`。
- **无出边（开放区间）**：不强制下一站；选项以 stay「继续」为主，可 `end`「告一段落」；失败保底同此。
- **禁止（有骨架时）**：擅自增删主节点、发明不存在的下一站 id。
- **聊天**：不走区间拍；见上节产品形态。

### 收敛（有出边时）

1. **下一站集合封闭**：只能进入邻接节点或声明的结局。
2. **目标锚定**：服务本站 synopsis 并接到合法下一站。
3. **失败可拉回**：保底「前往：下一站」指向合法出边。
4. **有限回合**：单区间拍数触顶后强制收敛选项（开放区间不触顶强制）。

字段级推进与存档见 [MainBeat.md](./MainBeat.md)。资源：场景图等仍以生图或导入挂槽；无图可先玩。

## 故事库与存档落点

对用户叫**故事**（代码类型仍是 `Project`）：一份可玩的故事包 = 设定 + 角色 + 情节脉络等，不是酒馆「角色卡」。

- **故事包**：`{library}/projects/{id}/`（manifest + project.json + assets）。
- **游玩存档**：`{library}/saves/{slotId}.json`（每故事可多槽；[`SaveRepository`](../lib/domain/repositories/save_repository.dart)）。字段含 `id`、`projectId`、`mode`，聊天另有 `chat[]`（[`TavernChatMessage`](../lib/domain/chat/tavern_chat_message.dart)：`id` / `role` / `content`，助手可选 `reasoning`）与 `replyChoices[]`；视觉小说另有 `pointer`（含 `lineIndex` / `phase`）、`bridge` 与本局 `history[]` + `historyCursor`（回退时间线）。故事详情「开始游玩」新建槽；开玩与每轮（聊天回合 / 视觉小说推进、回退与桥接段）自动写回该槽，无手动保存入口；删故事时 `clearForProject`。
- **库内文件夹**：`{library}/folders.json`（文件夹树 + 故事归属；[`ProjectFolder`](../lib/domain/models/project_folder.dart)）。文件夹只组织库浏览，不进故事包内容。

## Side（支线）

- **可拼装**：支线是可插入主线缝隙的模块，不强制改写主线骨架。
- **定式**：可复用的叙事模板（如偶遇、冲突、交易、告白），带槽位（参与角色、地点、冲突、奖励/后果）。
- **定式下的自由发挥**：同一模板由作者或 AI 填槽生成具体 Beats；模板稳定，实例可再编辑。与「主线区间 AI」类似，但挂在支线实例上，仍不得破坏主脉络合法出口。
- MVP：先支持少量内置定式 + 生成/手改一集支线，再谈定式市场或复杂编排。

## Beat / Scene（可运行单元）

双模式共用的最小播放单位。来源可以是**创作预写**或**游玩时 AI 写入（可只进存档会话，不必改故事包）**。字段与推进以 [MainBeat.md](./MainBeat.md) 为准；摘要如下：

| 概念 | 说明 |
| --- | --- |
| 所属 | 某主线 **Node**（或日后支线实例） |
| 场景 | `backgroundAssetId`、地点文案 |
| 出场 | 角色 + 立绘/表情/站位 |
| 对白 | `lines[]`（说话人 + 文本） |
| 选项 | `choices[]` → `Transition`（beat / node / end）；区间 AI 的关键收敛选项应落到合法 `node` / `end` |
| 无选项 | 下一 Beat → 否则按收敛规则给出下一主节点 / end |

- **VN 模式**：全屏背景 + 底部对白 + 点屏推进 + 中央选项；沿情节图骨架生长本局**剧情树**（拍 + 决策边），可回退改选复用；句内指针与树一并写入存档（见 [MainBeat.md](./MainBeat.md) §5）。
- **聊天模式**：酒馆式 transcript（`SaveSlot.chat`）；不复用 Beat 指针推进。

## 创作器 vs 运行时（内容视角）

| | 创作器 | 运行时 |
| --- | --- | --- |
| 读写 | 读写设定 / 角色 / **脉络骨架**（及可选预写 Beat）、定式 | 只读骨架 + 设定；写进度 / 存档；**可写本局剧情树**（`generatedBeats` + `branchEdges`） |
| AI | 生成世界观、角色、**主线节点与分支骨架**、润色；不负责整本逐句定稿 | **节点区间内实时生成与衔接**（全局 AiPreset + WorldBook + 本站/下一站 synopsis）；必须收敛 |
| ST | 仅角色卡等素材摘取 | 不出现 |

## 设计原则

1. **一份素材，两种玩法**：设定 / 角色 /（可选）情节共用；聊天与 VN 推进状态分开，禁止再把聊天硬绑回 Beat 桥接。
2. **脉络先于发挥（VN）**：先稳定 WorldBook / Main 骨架，再在游玩（或预写）中填 Beats。
3. **骨架封闭、区间开放（VN）**：玩家选择改变的是「走哪条已有分支」，不是「AI 另造主线地图」。
4. **自由发挥必须收敛（VN）**：区间 AI 可以花，但不能堵死通往下一主节点或合法结局的路。
5. **聊天回合清晰**：助手一轮、用户一轮；回复选项只充当用户发言。
6. **定式可复用，实例可覆盖**：Side 模板不直接等于最终对白。
7. **设定与预设分离**：事实进 WorldBook；采样与提示词进全局 AiPreset。
8. **预设可切换、可复用**：换全局预设改变口吻与采样，不改节点图与故事包。
9. **按需扩展**：字段与层服务当前闭环；不为兼容 ST 预留空抽象。
