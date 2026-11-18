/// Task suffixes appended after global AiPreset for create tools.
class CreatePromptProfiles {
  const CreatePromptProfiles._();

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