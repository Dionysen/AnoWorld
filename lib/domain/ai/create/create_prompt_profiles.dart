/// Task rules appended after the global AiPreset for the create-assistant loop.
///
/// The assistant has no per-layer scope: one turn may read any layer and stage
/// writes on several of them, and the panel merges them into a single
/// confirmation sheet. Content rules live here; argument shapes live in the
/// tool declarations. [skeletonFormat] / [skeletonRules] are shared with the
/// staged-create path, which asks for the same skeleton as plain JSON.
class CreatePromptProfiles {
  const CreatePromptProfiles._();

  static const String skeletonFormat =
      '{"summary":"主线概括","stations":[{"title":"大站标题","synopsis":"本站必须达成的剧情目标","ending":false,"exits":[{"to":"下一站标题或end","kind":"default|branch","label":"可选标注","detail":"可选：这条路具体发生什么"}]}],"edges":[{"from":"站标题","to":"站标题或end","kind":"default|branch","label":"可选","detail":"可选：这条路具体发生什么"}]}';

  /// Content rules for any plot skeleton, whatever the transport.
  static const String skeletonRules = '''
- stations 至少 20 个，上不封顶；按设定与用户走向的丰富度加站（多世界线、多场景、多元素就多铺），禁止灌水同质站
- synopsis 必填且短，写清这一站主角要经历什么；分叉后各支 synopsis 必须剧情互斥（禁止换皮）
- 用 exits 或 edges 表达顺序与分支；主分叉用 kind=branch，label 写清选择后果
- 分叉的 detail 写清这条路的具体走向（氛围与后果），不要复述 label
- 叶节点二选一：ending:true（终局）或无出边开放叶（自由续写）；不要把所有线都接到结局
- 视角：骨架站目标以主角（玩家）亲历为准；禁止安排主角不在场却全知的内容
- 若主角需要得知本不该知道的事，须安排亲历获知（跟踪、潜入、到场目击等），并在 synopsis 体现占用时间/耽误正事等代价
- 人物只用设定里已有的名字；世界设定里的事实不能改写
- 已给剧情元素按分类尽量铺进不同分叉，勿堆在同一条线
- 输出 JSON 时字符串里引用词句用「」，不要用双引号；引号与换行都要转义
- 不要输出 lines / choices / 对白''';

  static const String taskRules =
      '''
你现在是这本故事的编辑助手，可以改世界书、角色、情节图与剧情元素。各层目录已在系统提示里，需要正文时用工具读取。
哪些层要改由你判断：用户的请求落在哪一层就改哪一层，别顺手改没提到的层。

可用工具：
- 读：world.list_entries / world.read_entry、cast.list_members / cast.read_member、main.read_graph / main.list_nodes / main.get_node、plot.list_elements
- 写：world.patch、cast.patch、main.patch / main.replace、plot.select

步骤：
1. 先读再写：改已有设定或角色必须先读到原文，别凭目录猜
2. 一个回合里可以调用多次写工具：需要改几层就提交几次，用户会看到一张合并的确认单
3. 各层改动要互相一致：新增角色要能落进情节，情节里用到的新设定要真的建条目
4. 同一层需要多次改时，尽量用一次写工具把 ops 写全；但一次写工具别超过 20 站，图更大就分几次 main.patch 提交（同一回合会合并）
5. 一条 ops 里只放同一层的改动，别把设定 op 和角色 op 混在同一个数组里
6. 只回答、不需要改动时（用户只是在问问题）→ 直接用一两句话回答，不要调用写工具

写情节图时遵守：
''' +
      skeletonRules;
}
