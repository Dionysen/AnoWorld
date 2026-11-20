/// Task suffixes appended after global AiPreset for create tools.
class CreatePromptProfiles {
  const CreatePromptProfiles._();

  /// Stations + edges only; play fills beats per interval (docs/MainBeat.md).
  static const String mainGraphTaskSuffix = '''
输出格式（只出脉络骨架，不要对白）：
{"summary":"主线概括","stations":[{"title":"大站标题","synopsis":"本站必须达成的剧情目标","ending":false,"exits":[{"to":"下一站标题或end","kind":"default|branch","label":"可选标注"}]}],"edges":[{"from":"站标题","to":"站标题或end","kind":"default|branch","label":"可选"}]}
规则：
- stations 至少 20 个，上不封顶；按设定与用户走向的丰富度加站（多世界线、多场景、多元素就多铺），禁止灌水同质站
- synopsis 必填且短，写清这一站主角要经历什么；分叉后各支 synopsis 必须剧情互斥（禁止换皮）
- 用 exits 或 edges 表达顺序与分支；主分叉用 kind=branch，label 写清选择后果
- 叶节点二选一：ending:true（终局）或无出边开放叶（自由续写）；不要把所有线都接到结局
- 视角：骨架站目标以主角（玩家）亲历为准；禁止安排主角不在场却全知的内容
- 若主角需要得知本不该知道的事，须安排亲历获知（跟踪、潜入、到场目击等），并在 synopsis 体现占用时间/耽误正事等代价
- 人物只用设定里已有的名字；世界设定里的事实不能改写
- 已给剧情元素按分类尽量铺进不同分叉，勿堆在同一条线
- 不要输出 lines / choices / 对白
- 只输出 JSON，不要 markdown，不要解释''';

  /// Incremental graph ops only.
  static const String mainGraphPatchTaskSuffix = '''
你是情节图编辑助手。根据现有骨架与用户意图，只输出补丁 ops JSON，不要整图重写。
输出格式：
{"ops":[
  {"op":"set_summary","summary":"新概括"},
  {"op":"upsert_node","id":"可选已有id","title":"站名","synopsis":"目标","ending":false},
  {"op":"remove_node","id":"站id"},
  {"op":"upsert_edge","id":"可选","from":"站id或站名","to":"站id或站名或end","kind":"default|branch","label":"可选"},
  {"op":"remove_edge","id":"边id"}
]}
规则：
- 只改用户提到的部分；未提及的站与边保持不动
- 分叉后 synopsis 要拉开差异；开放叶可不给出边；终局用 ending:true 或 to=end
- 视角与知情代价同全量骨架：主角亲历，禁止上帝全知
- 只输出 JSON，不要 markdown，不要解释''';

  static const String worldPatchTaskSuffix = '''
你是世界书编辑助手。根据现有设定与用户意图，只输出条目补丁 ops JSON。
输出格式：
{"ops":[
  {"op":"upsert_entry","id":"可选已有id","title":"标题","body":"正文","alwaysOn":true,"keys":["可选关键词"]},
  {"op":"remove_entry","id":"条目id"}
]}
规则：
- 只改用户提到的设定；不要无故删光
- 新建可不带 id；改已有必须带 id
- 只输出 JSON，不要 markdown，不要解释''';

  static const String castPatchTaskSuffix = '''
你是角色编辑助手。根据现有角色与用户意图，只输出角色补丁 ops JSON。
输出格式：
{"ops":[
  {"op":"upsert_member","id":"可选已有id","name":"名字","summary":"简介","personality":"性格","speechStyle":"口吻","isProtagonist":false},
  {"op":"remove_member","id":"角色id"}
]}
规则：
- 只改用户提到的角色；不要无故删光
- 新建可不带 id；改已有必须带 id
- 只输出 JSON，不要 markdown，不要解释''';

  static const String organizeCardTaskSuffix = '''
你是角色卡导入整理助手。只做分类与归位，禁止改写、润色、发挥。
只输出 JSON，不要 markdown 代码块，不要解释。

输出格式：
{"operations":[
  {"op":"extract_to_cast","fromSourceId":"world:条目id","castItemId":"已有角色id","target":"cast.summary|cast.personality|cast.speechStyle","body":"必须从该 world 正文复制的子串"},
  {"op":"add_cast","fromSourceId":"world:条目id","name":"角色名","body":"该角色整段原文子串","target":"cast.personality"},
  {"op":"split_cast","fromSourceId":"world:条目id","casts":[
    {"name":"角色A","personality":"A的原文子串"},
    {"name":"角色B","castItemId":"已有id","summary":"B的原文子串"}
  ]},
  {"op":"update_world","fromSourceId":"world:条目id","body":"去掉角色段落后剩的世界观子串（须仍是原文子串）"},
  {"op":"split_world","fromSourceId":"world:条目id","entries":[{"title":"设定标题","body":"必须是来源正文的子串","alwaysOn":true,"keys":[]}]},
  {"op":"noop","fromSourceId":"来源id"}
]}
规则：
- 重点扫描 kind 为 worldBook.body：一条里有多名角色时，优先用 split_cast 一次拆出多名（casts 数组）；或多次 add_cast / extract_to_cast，每人一段必须是原文子串
- 角色卡排版各异：常见有【名】、行首「专名: 叙述」、### 标题、**粗体名** 等，按正文语义辨认人物专名，不要猜固定模板
- name 必须是原文里真实出现的人名锚点（同一行「名:」、或【名】、或标题行专名），不要把属性表字段（骰子、持有物品、基础属性等）或势力/地区/栏目名当人
- 能对应上已有 castItemId（同名主角等）用 castItemId；其余用 name 新建配角
- 不含角色人设的 world 条目一律 noop，不要硬拆
- 所有 body 必须是 fromSourceId 对应正文的连续子串，不得 paraphrase
- 不要 delete，不要编造新事实
- 不要用 op move（已废弃）
''';
}
