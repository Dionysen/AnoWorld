/// Task suffixes appended after global AiPreset for create tools.
class CreatePromptProfiles {
  const CreatePromptProfiles._();

  /// Stations + edges only; play fills beats per interval (docs/MainBeat.md).
  static const String mainGraphTaskSuffix = '''
输出格式（只出脉络骨架，不要对白）：
{"summary":"主线概括","stations":[{"title":"大站标题","synopsis":"本站必须达成的剧情目标","ending":false,"exits":[{"to":"下一站标题或end","kind":"default|branch","label":"可选标注","detail":"可选：这条路具体发生什么"}]}],"edges":[{"from":"站标题","to":"站标题或end","kind":"default|branch","label":"可选","detail":"可选：这条路具体发生什么"}]}
规则：
- stations 至少 20 个，上不封顶；按设定与用户走向的丰富度加站（多世界线、多场景、多元素就多铺），禁止灌水同质站
- synopsis 必填且短，写清这一站主角要经历什么；分叉后各支 synopsis 必须剧情互斥（禁止换皮）
- 用 exits 或 edges 表达顺序与分支；主分叉用 kind=branch，label 写清选择后果
- 分叉的 detail 写清这条路的具体走向（氛围与后果），不要复述 label
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
  {"op":"upsert_edge","id":"可选","from":"站id或站名","to":"站id或站名或end","kind":"default|branch","label":"可选","detail":"可选：这条路具体发生什么"},
  {"op":"remove_edge","id":"边id"}
]}
规则：
- 只改用户提到的部分；未提及的站与边保持不动
- 分叉后 synopsis 要拉开差异；开放叶可不给出边；终局用 ending:true 或 to=end
- detail 写清这条路的具体走向（氛围与后果）；用户没提到 detail 就不要编
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
  {"op":"upsert_member","id":"可选已有id","name":"名字","summary":"简介","personality":"性格","speechStyle":"口吻","exampleLines":["可选例句"],"isProtagonist":false},
  {"op":"remove_member","id":"角色id"}
]}
规则：
- 只改用户提到的角色；不要无故删光
- 新建可不带 id；改已有必须带 id
- exampleLines 是说话风格示例，每条一句，带不带名字前缀都行；不改就别输出该字段
- 只输出 JSON，不要 markdown，不要解释''';
}
