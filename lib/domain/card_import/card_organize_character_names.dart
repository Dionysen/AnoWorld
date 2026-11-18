/// Reject stat-sheet labels and section buckets — not a format-specific roster parser.
abstract final class CardOrganizeCharacterNames {
  static const Set<String> fieldLabels = {
    '骰子',
    '位置',
    '时间',
    '姓名',
    '境界',
    '所属势力',
    '技艺',
    '生命',
    '灵力',
    '属性',
    '背景',
    '设定',
    '世界观',
    '规则',
    '技能',
    '等级',
    '性别',
    '年龄',
    '种族',
    '职业',
    '好感',
    '状态',
    '物品',
    '装备',
    '关系',
    '场景',
    '地点',
    '势力',
    '阵营',
    '介绍',
    '描述',
    '性格',
    '外貌',
    '身份',
    '持有物品',
    '基础属性',
    '特殊气运',
    '法宝',
    '成员',
    '别名',
    '注',
    'hp',
    'mp',
    'name',
    'age',
  };

  static final RegExp _categorySuffix = RegExp(
    r'(物品|属性|气运|法宝|备注|说明|设定|规则|体系|模板|字段|板块|分区|栏目)$',
  );

  static bool isFieldLabel(String name) {
    final trimmed = name.trim();
    final n = trimmed.toLowerCase();
    if (n.isEmpty) return true;
    if (fieldLabels.contains(trimmed)) return true;
    if (fieldLabels.contains(n)) return true;
    if (_categorySuffix.hasMatch(trimmed)) return true;
    if (trimmed.contains('/') || trimmed.contains('、')) return true;
    return false;
  }

  /// New cast name: passes field-label check and has enough attached text when known.
  static bool isPlausibleNewCharacterName(String name, {int bodyChars = 0}) {
    if (isFieldLabel(name)) return false;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    if (RegExp(r'^\d+$').hasMatch(trimmed)) return false;
    if (trimmed.length == 1) {
      return bodyChars >= 6;
    }
    if (trimmed.length <= 3 && bodyChars > 0) {
      return bodyChars >= 4;
    }
    if (bodyChars > 0 && bodyChars < 8) return false;
    return true;
  }
}