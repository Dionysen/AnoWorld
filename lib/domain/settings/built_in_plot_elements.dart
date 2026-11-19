import 'package:anoworld/domain/models/plot_element.dart';

/// Factory seed list for the global plot-element catalog.
abstract final class BuiltInPlotElements {
  static const List<PlotElement> all = <PlotElement>[
    PlotElement(
      id: 'pe_stray_cat',
      keyword: '救助流浪猫',
      description:
          '主角或同伴遇见受伤/受惊的流浪猫，被迫分心照料。示例：雨夜门口蜷着一只湿透的猫，不救会心不安，救了却拖慢正事。',
    ),
    PlotElement(
      id: 'pe_lost_child',
      keyword: '捡到迷路小孩',
      description:
          '短暂照管走失的孩子，引出善意、怀疑或家长冲突。示例：巷口小孩死抓你袖口说找不到妈妈，围观目光开始打量你。',
    ),
    PlotElement(
      id: 'pe_shared_umbrella',
      keyword: '雨夜共伞',
      description:
          '被迫与人共一把伞，拉近距离或制造暧昧尴尬。示例：暴雨里只剩一把伞，对方已湿透，不让会像见死不救。',
    ),
    PlotElement(
      id: 'pe_borrow_fire',
      keyword: '邻里借火',
      description:
          '因琐事敲门求助，打开不该开的社交缝隙。示例：隔壁来借火或盐，话里却透出对你行程的过分好奇。',
    ),
    PlotElement(
      id: 'pe_lost_and_found',
      keyword: '旧物失而复得',
      description:
          '遗失信物意外回到手上，勾起回忆或阴谋。示例：以为丢了的钥匙/手帕被人送回，上面多了一道划痕。',
    ),
    PlotElement(
      id: 'pe_anonymous_letter',
      keyword: '匿名来信',
      description:
          '收到不明来信，内容半真半假逼人选择。示例：门缝塞进纸条，只写「别去那里」，没有落款。',
    ),
    PlotElement(
      id: 'pe_brief_companion',
      keyword: '同路人短暂同行',
      description:
          '一段路与陌生人结伴，交换情报后分开。示例：夜路上有人说同路，聊了两句却像知道你要去哪。',
    ),
    PlotElement(
      id: 'pe_public_shame',
      keyword: '当众出丑',
      description:
          '在众人面前失手/失态，名声或自尊受损。示例：席间杯子打翻，衣襟污了，哄笑声盖过你要说的话。',
    ),
    PlotElement(
      id: 'pe_mistaken_identity',
      keyword: '被认错人',
      description:
          '被人当成另一个人，卷入对方的恩怨。示例：有人突然喊错名字拉你走，解释不清越描越黑。',
    ),
    PlotElement(
      id: 'pe_overhear',
      keyword: '听见不该听的话',
      description:
          '无意偷听到关键对话，知道了不该知道的。示例：墙后传来交易或威胁，你一动，对方立刻噤声。',
    ),
    PlotElement(
      id: 'pe_stranger_greeting',
      keyword: '被当成熟人搭话',
      description:
          '陌生人用熟络口吻接近，试探或设套。示例：有人拍肩叫你旧绰号，你从未听过那个名字。',
    ),
    PlotElement(
      id: 'pe_others_quarrel',
      keyword: '卷入别人的争吵',
      description:
          '路过纠纷被点名作证或拉偏架。示例：两人对骂，忽然指向你：「你刚才都看见了！」',
    ),
    PlotElement(
      id: 'pe_failed_favor',
      keyword: '请托办砸',
      description:
          '答应帮小忙却搞砸，欠下人情或惹祸。示例：本只是代传一句话，结果话传到了最不该听的人耳中。',
    ),
    PlotElement(
      id: 'pe_bullying',
      keyword: '霸凌排挤',
      description:
          '被群体冷落、羞辱或孤立，逼出反抗或隐忍。示例：议事时无人应你，背后却传开难听的绰号。',
    ),
    PlotElement(
      id: 'pe_extortion',
      keyword: '敲诈勒索',
      description:
          '以把柄或暴力索要钱物/服从。示例：有人亮出一张你不想公开的纸，笑着开价。',
    ),
    PlotElement(
      id: 'pe_stalking',
      keyword: '被跟踪',
      description:
          '感到或确认有人尾随，安全感崩塌。示例：连拐三条巷，身后脚步仍不远不近。',
    ),
    PlotElement(
      id: 'pe_frame_up',
      keyword: '诬陷栽赃',
      description:
          '被栽赃成凶手/小偷，需自证或逃亡。示例：包里多出不属于你的血帕，搜查的人正好到来。',
    ),
    PlotElement(
      id: 'pe_public_humiliation',
      keyword: '当众羞辱',
      description:
          '对方故意在众人前贬低你，撕裂关系。示例：宴上有人高声揭你短处，全场安静等你反应。',
    ),
    PlotElement(
      id: 'pe_power_abuse',
      keyword: '权力欺压',
      description:
          '门卫、差役、债主等用职权刁难。示例：门口的人说「上面有令」，不塞钱就不放行。',
    ),
    PlotElement(
      id: 'pe_witness_fight',
      keyword: '目睹斗殴',
      description:
          '撞见暴力冲突，选择旁观、劝架或报警式求助。示例：巷口两人扭打，刀光一闪，你成了唯一目击者。',
    ),
    PlotElement(
      id: 'pe_murder_trace',
      keyword: '撞见杀机',
      description:
          '发现尸体、血迹或抛尸痕迹，卷入命案。示例：井边有未干的血手印，远处有人回头看了你一眼。',
    ),
    PlotElement(
      id: 'pe_brief_hostage',
      keyword: '短暂挟持',
      description:
          '被挟持片刻做人质或挡箭牌，再脱身。示例：有人从暗处勒住你脖子，低声说「别出声，带我出去」。',
    ),
    PlotElement(
      id: 'pe_drugged',
      keyword: '中毒下药',
      description:
          '饮用或接触下了药的东西，意识模糊。示例：茶味发苦，站起来时地面开始倾斜。',
    ),
    PlotElement(
      id: 'pe_locked_room',
      keyword: '密室困人',
      description:
          '被锁在房间/厢房/地窖，须找出口或等人。示例：门在身后落下，窗也钉死，只剩一息灯火。',
    ),
    PlotElement(
      id: 'pe_voyeur',
      keyword: '偷窥',
      description:
          '撞见偷窥或被偷窥，羞耻与危险并存。示例：你推门看见有人贴窗窥视；或发现自己的窗缝被人拨开。',
    ),
    PlotElement(
      id: 'pe_recurring_dream',
      keyword: '重复梦见',
      description:
          '同一幕反复入梦，暗示真相或诅咒。示例：连续三夜梦见同一扇红门，门后总有人叫你的名字。',
    ),
    PlotElement(
      id: 'pe_wrong_echo',
      keyword: '不该有的回声',
      description:
          '空处传来回声或人声，打破日常逻辑。示例：无人走廊里，你的脚步多出半拍回响。',
    ),
    PlotElement(
      id: 'pe_object_moves',
      keyword: '物件自移',
      description:
          '东西自己换位，制造不安或线索。示例：锁好的抽屉夜里开了，里面多了一枚陌生纽扣。',
    ),
    PlotElement(
      id: 'pe_memory_gap',
      keyword: '失忆断片',
      description:
          '短暂失去一段记忆，醒来位置不对。示例：你记得推门进去，下一秒已站在屋外，衣袖湿了。',
    ),
    PlotElement(
      id: 'pe_omen',
      keyword: '预兆巧合',
      description:
          '偶然翻到一句与眼前事吻合的话。示例：随手翻开的书，那页正好写着你刚听到的地名。',
    ),
    PlotElement(
      id: 'pe_found_key',
      keyword: '捡到信物',
      description:
          '捡到钥匙、玉佩、信件等，打开新线。示例：泥地里半枚铜钥匙，齿形与你家旧锁莫名相合。',
    ),
    PlotElement(
      id: 'pe_small_gamble',
      keyword: '小赌运气',
      description:
          '一次小赌赢或输，改变资源或关系。示例：路边人邀你猜枚，赌注只是一句话的承诺。',
    ),
    PlotElement(
      id: 'pe_saved_by_stranger',
      keyword: '被陌生人救命',
      description:
          '危急时被路人救下，欠下一笔人情。示例：落水或遇袭时有人拉你一把，留下姓名便走。',
    ),
    PlotElement(
      id: 'pe_secret_glimpse',
      keyword: '瞥见秘密身份',
      description:
          '无意看见某人另一面身份的一角。示例：对方换装出门，腰间多了一枚你不该认识的印信。',
    ),
    PlotElement(
      id: 'pe_wrong_door',
      keyword: '走错门',
      description:
          '进错房间或院落，撞见另一场域。示例：以为是客栈侧门，推开却是香火未冷的秘坛。',
    ),
    PlotElement(
      id: 'pe_same_sex_tension',
      keyword: '同性恋',
      description:
          '同性别之间的爱慕、试探或压抑关系，可织进支线情感。示例：并肩赶路时对方忽然放慢步子，像怕被别人听见表白。',
    ),
    PlotElement(
      id: 'pe_sm_power',
      keyword: 'SM',
      description:
          '支配/服从、束缚或疼痛边缘的玩法张力，按故事尺度点到为止。示例：一句话约定「今晚听我的」，绳结只系在袖口作暗示。',
    ),
    PlotElement(
      id: 'pe_forbidden_affair',
      keyword: '禁忌私情',
      description:
          '不该发生的亲密（身份差、已婚、敌对），一旦暴露代价大。示例：宴后廊下短暂触手，身后屏风却动了一下。',
    ),
    PlotElement(
      id: 'pe_jealousy',
      keyword: '吃醋误会',
      description:
          '因误会生妒，推动争吵或澄清。示例：看见对方与人说笑，你转身就走，对方却在追解释。',
    ),
    PlotElement(
      id: 'pe_blackmail_intimacy',
      keyword: '以情挟制',
      description:
          '用亲密把柄或旧情要挟行动。示例：旧人寄来一缕头发与半封旧信，要求你今晚必须到场。',
    ),
  ];

  static final Map<String, PlotElement> byId = {
    for (final e in all) e.id: e,
  };

  static bool containsId(String id) => byId.containsKey(id);
}
