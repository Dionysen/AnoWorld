import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:flutter/widgets.dart';

/// Simplified Chinese copy.
///
/// The only shipped language for now; adding another means writing one more
/// `AppStrings` subclass and listing it in [AppStringsSetup.translations].
class AppStringsZh extends AppStrings {
  const AppStringsZh();

  @override
  Locale get locale => const Locale('zh');

  @override
  String get languageLabel => '简体中文';

  // Foundation chrome.

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String get more => '更多';

  @override
  String get loading => '加载中…';

  @override
  String get retry => '重试';

  @override
  String get keepEditing => '继续编辑';

  @override
  String get discard => '放弃';

  @override
  String get discardEditsTitle => '放弃这次修改？';

  @override
  String get discardEditsDetail => '还没保存的改动会丢掉';

  // Shared rows.

  @override
  String get listSeparator => '、';

  @override
  String get unnamed => '未命名';

  @override
  String get noDescription => '还没写描述';

  @override
  String get builtInTag => '默认';

  @override
  String get builtInEditedTag => '默认 · 已改';

  @override
  String countLabel(int count) => count == 0 ? '还空着' : '$count 条';

  @override
  String get uncategorized => '未分类';

  // Plot-element library.

  @override
  String get plotElementsLibraryTitle => '剧情元素库';

  @override
  String get tabAll => '全部';

  @override
  String get tabCategorized => '分类';

  @override
  String get tabPacks => '包';

  @override
  String get addOne => '加一条';

  @override
  String get newCategory => '新建分类';

  @override
  String get newPack => '新建包';

  @override
  String get libraryEmptyMessage => '库是空的';

  @override
  String get libraryEmptyDetail => '加一条，或全部恢复默认';

  @override
  String get packsEmptyMessage => '还没有包';

  @override
  String get packsEmptyDetail => '把常用的元素打包，创作时一次勾上';

  @override
  String get restoreAllBuiltIns => '全部恢复默认';

  @override
  String get restoreAllBuiltInsHint => '出厂条目恢复原文并补回已删的';

  @override
  String get restoreAllConfirmTitle => '全部恢复默认？';

  @override
  String get restoreAllConfirmDetail => '出厂条目会恢复原文并补回已删的；你自己加的保留';

  @override
  String get restoreAllConfirmLabel => '全部恢复';

  @override
  String get renameCategory => '重命名分类';

  @override
  String get newCategoryTitle => '新分类';

  @override
  String get categoryEmptyMessage => '这个分类还空着';

  @override
  String get categoryEmptyDetail => '加一条，或在编辑条目时改分类';

  @override
  String get categoryEmptyPickDetail => '去玩法里把元素挪进来';

  @override
  String get categoryNameHint => '日常、情感、危机…';

  // Packs.

  @override
  String get renamePack => '重命名包';

  @override
  String get deletePack => '删除包';

  @override
  String get deletePackTitle => '删除这个包？';

  @override
  String get deletePackEmptyDetail => '包是空的';

  @override
  String packDeleteDetail(int count) => '包里的 $count 条元素仍留在库里';

  @override
  String get packEmptyLibraryDetail => '去剧情元素库加一条';

  @override
  String get packMissing => '这个包已经不在了';

  @override
  String get packTitleFallback => '包';

  @override
  String get packNameHint => '雨夜悬疑、校园日常…';

  @override
  String packSummary(int count, String preview) => '$count 条 · $preview';

  @override
  String packAppliedCount(int applied, int total) => '已选 $applied / $total 条';

  @override
  String packOverlapTitle(String packName) => '「$packName」和已选元素有重叠';

  @override
  String packApplyImpact(PackApplyPlanText plan) {
    final names = plan.overlapNames.map((name) => '「$name」').join('');
    return <String>[
      if (plan.addedCount > 0) '新增 ${plan.addedCount} 条',
      if (plan.manualSharedCount > 0)
        '其中 ${plan.manualSharedCount} 条你单独勾过，会算作这个包的一部分；取消这个包时也会一起取消',
      if (plan.overlappedCount > 0)
        '其中 ${plan.overlappedCount} 条已被$names用到，取消这个包时会保留',
    ].join('；');
  }

  @override
  String packRemoveTitle(String packName) => '取消「$packName」？';

  @override
  String packRemoveImpact(PackRemovePlanText plan) {
    final names = plan.keptByNames.map((name) => '「$name」').join('');
    final kept = '${plan.keptCount} 条仍被$names用到，会保留';
    if (plan.removedCount == 0) return kept;
    return '$kept；其余 ${plan.removedCount} 条会取消勾选';
  }

  @override
  String get applyAnyway => '仍然应用';

  @override
  String get uncheck => '取消勾选';

  // Story-side picker.

  @override
  String get plotElementsTitle => '剧情元素';

  @override
  String get manageLibrary => '管理库';

  @override
  String get openStoryFailed => '无法打开故事';

  @override
  String get libraryEmptyPickDetail => '去玩法里管理库';

  @override
  String get goManageLibrary => '去管理库';

  @override
  String get packsEmptyPickDetail => '去剧情元素库把常用元素打包';

  @override
  String selectedCount(int count) => '已选 $count';

  // Element editor.

  @override
  String get newElementTitle => '新剧情元素';

  @override
  String get editElementTitle => '编辑剧情元素';

  @override
  String get keywordLabel => '关键词';

  @override
  String get keywordHint => '救助流浪猫、雨夜共伞…';

  @override
  String get categoryLabel => '分类';

  @override
  String get descriptionLabel => '描述';

  @override
  String get descriptionHint => '说明怎么用，再写一句示例剧情';

  @override
  String maxChars(int count) => '最多 $count 字';

  @override
  String get generateDescription => '生成描述';

  @override
  String get generating => '正在写…';

  @override
  String get generateFailed => '没写出来，请稍后再试';

  @override
  String get restoreDefault => '恢复默认';

  @override
  String get deleteElementTitle => '删除这个剧情元素？';

  @override
  String get deleteElementBuiltInDetail => '可从菜单「全部恢复默认」再加回来';

  @override
  String get deleteElementCustomDetail => '删掉后无法恢复';

  // Home navigation.

  @override
  String get tabSessions => '会话';

  @override
  String get tabStories => '故事';

  @override
  String get tabPlayModes => '玩法';

  @override
  String get tabMe => '我';

  @override
  String get settingsTitle => '设置';

  @override
  String folderCount(int count) => '$count 个文件夹';

  @override
  String storyCount(int count) => '$count 个故事';

  @override
  String get emptyFolder => '空文件夹';

  @override
  String get addAction => '添加';

  @override
  String get plotElementsHubHint => '全局库，给故事勾着用';

  @override
  String get aiPresetTitle => '预设';

  @override
  String get aiPresetHubHint => '输出风格、采样与提示词';

  @override
  String get noPersonaYet => '还没有身份';

  // Stories tab.

  @override
  String get browseRoot => '故事';

  @override
  String get searchStoriesHint => '搜索故事';

  @override
  String get untitledStory => '未命名故事';

  @override
  String get storyOptions => '故事选项';

  @override
  String get moveToFolder => '移到文件夹';

  @override
  String get displayMode => '显示方式';

  @override
  String get avatarShape => '头像形状';

  @override
  String get viewModeDetailedList => '详细列表';

  @override
  String get viewModeSimpleList => '简洁列表';

  @override
  String get viewModeGrid => '网格';

  @override
  String get viewModeCompactGrid => '紧凑网格';

  @override
  String get avatarCircle => '圆形头像';

  @override
  String get avatarSquare => '方形头像';

  @override
  String get avatarRectangle => '矩形头像';

  @override
  String get noMatchingStories => '没有匹配的故事';

  @override
  String createFailed(Object error) => '新建失败：$error';

  @override
  String sampleWriteFailed(Object error) => '样例写入失败：$error';

  @override
  String importedStory(String title) => '已导入「$title」';

  @override
  String importFailed(Object error) => '导入失败：$error';

  @override
  String get pickStoryFolderTitle => '选择 AnoWorld 故事包文件夹';

  @override
  String get nameLabel => '名称';

  @override
  String get folderNameHint => '文件夹名称';

  @override
  String get newFolder => '新建文件夹';

  @override
  String get renameFolder => '重命名文件夹';

  @override
  String createFolderFailed(Object error) => '新建文件夹失败：$error';

  @override
  String renameFolderFailed(Object error) => '重命名失败：$error';

  @override
  String deleteFolderFailed(Object error) => '删除文件夹失败：$error';

  @override
  String dissolveFolderFailed(Object error) => '解散失败：$error';

  @override
  String moveFailed(Object error) => '移动失败：$error';

  @override
  String deleteFolderTitle(String name) => '删除「$name」？';

  @override
  String get deleteFolderDetail => '里面的故事会回到上一层';

  @override
  String dissolveFolderTitle(String name) => '解散「$name」？';

  @override
  String get dissolveFolderDetail => '文件夹会去掉，内容留在上一层';

  @override
  String get dissolve => '解散';

  @override
  String deleteItemsTitle(int count) => '删除这 $count 项？';

  @override
  String get deleteItemsDetail => '故事会彻底删掉，文件夹里的故事会回到上一层';

  @override
  String get moveToTitle => '移到…';

  @override
  String get allStories => '全部故事';

  @override
  String get deleteStoryTitle => '删除这个故事？';

  @override
  String get deleteStoryDetail => '故事和对应存档都会删掉';

  @override
  String updatedOn(String date) => '更新 $date';

  @override
  String get openAction => '打开';

  @override
  String get renameAction => '重命名';

  @override
  String get dissolveFolderAction => '解散文件夹';

  @override
  String get deleteFolderAction => '删除文件夹';

  @override
  String get playStory => '开始故事';

  @override
  String get viewStory => '查看故事';

  @override
  String get editStory => '编辑故事';

  @override
  String get deleteStory => '删除故事';

  @override
  String cannotStart(Object error) => '无法开始：$error';

  @override
  String get newBlankStory => '新建空白故事';

  @override
  String get pasteStory => '粘贴故事';

  @override
  String get stagedPrompts => '分阶段提示词';

  @override
  String get importCard => '导入角色卡';

  @override
  String get importStoryPack => '导入故事包';

  @override
  String get trySampleStory => '试用「雨夜投宿」';

  // Story hub.

  @override
  String get changeCover => '更换封面';

  @override
  String get cannotChangeCover => '当前故事还不能换封面';

  @override
  String coverFailed(Object error) => '无法更换封面：$error';

  @override
  String get coverSection => '封面';

  @override
  String get chooseImage => '选择图片';

  @override
  String get unnamedEntry => '未命名条目';

  @override
  String get unnamedCast => '未命名角色';

  @override
  String get tagAlwaysOn => '常驻';

  @override
  String get tagOnDemand => '按需';

  @override
  String get tagProtagonist => '主角';

  @override
  String get tagExampleLines => '示例对白';

  @override
  String get mainSummaryTitle => '脉络摘要';

  @override
  String get tagSummary => '概要';

  @override
  String get noMainStations => '还没有大情节站';

  @override
  String mainStops(int stops, int edges) => '$stops 站 · $edges 条连线';

  @override
  String get continueCreating => '继续创作';

  @override
  String get startPlaying => '开始游玩';

  @override
  String get createHubUntitled => '创作·未命名故事';

  @override
  String createHubTitle(String name) => '创作·$name';

  @override
  String get worldBookTitle => '世界书';

  @override
  String get castTitle => '角色';

  @override
  String get mainTitle => '情节走向';

  @override
  String get worldBookEmpty => '还没有世界观与设定';

  @override
  String get castEmpty => '还没有角色';

  @override
  String get plotElementsEmpty => '还没选剧情元素';

  @override
  String worldBookSize(int entries, int alwaysOn, int tokens) {
    if (entries == 0) return '还没有设定条目';
    return '$entries 条设定，$alwaysOn 条常驻，$tokens token';
  }

  @override
  String castSize(int members, int tokens) {
    if (members == 0) return '还没有角色';
    return '$members 个角色，$tokens token';
  }

  @override
  String mainSize(int nodes, int tokens) {
    if (nodes == 0) return '还没有情节节点';
    return '$nodes 个节点，$tokens token';
  }

  @override
  String plotElementsSize(int selected, int tokens) {
    if (selected == 0) return '还没选';
    return '已选 $selected 项，$tokens token';
  }

  // Play.

  @override
  String get howToPlay => '怎么玩';

  @override
  String get visualNovelModeHint => '舞台与对白框，点一下往下看';

  @override
  String get chatModeHint => '一轮你、一轮角色，可点回复选项';

  @override
  String get chatSettingsTitle => '聊天设置';

  @override
  String get readingSection => '阅读';

  @override
  String get readingSectionHint => '只影响聊天气泡里的正文';

  @override
  String get lineHeight => '行距';

  @override
  String get paragraphSpacing => '段间距';

  @override
  String get bubblesSection => '气泡';

  @override
  String get bubbleRadius => '气泡圆角';

  @override
  String get showReasoning => '显示思考过程';

  @override
  String get showReasoningHint => '模型有思考内容时，折叠在气泡上方';

  @override
  String get avatarsSection => '头像';

  @override
  String get characterAvatar => '角色头像';

  @override
  String get characterAvatarHint => '助手气泡旁显示';

  @override
  String get myAvatar => '我的头像';

  @override
  String get myAvatarHint => '自己气泡旁显示';

  @override
  String get avatarAboveBubble => '头像在气泡上方';

  @override
  String get avatarAboveBubbleHint => '关闭后头像与气泡并排';

  @override
  String get backgroundSection => '背景';

  @override
  String get chatBackground => '聊天背景';

  @override
  String get backgroundPickerHint => '选一块铺在主题底色上';

  @override
  String get backgroundThemeDefault => '主题默认';

  @override
  String get backgroundThemeDefaultHint => '跟当前主题的聊天底色';

  @override
  String get backgroundSolid => '纯色';

  @override
  String get backgroundGradient => '内置渐变';

  @override
  String get gradientSection => '渐变';

  @override
  String get userLabelFallback => '我';

  @override
  String get castLabelFallback => '角色';

  @override
  String get narrator => '旁白';

  @override
  String get progressLoaded => '已读取进度';

  @override
  String get statusWriting => '正在写这一段…';

  @override
  String get statusTurnFailed => '这一轮暂时写不出来，请稍后再试';

  @override
  String get statusRestarted => '已从头开始';

  @override
  String get statusSafeExit => '用稳妥出口继续';

  @override
  String get fallbackBeatText => '这一段暂时写不出来，可以先用下方选项继续';

  @override
  String gotoNode(String name) => '前往：$name';

  @override
  String get regenerateReply => '重新生成回复';

  @override
  String get segmentEnded => '本段结束';

  @override
  String get restart => '重新开始';

  @override
  String get generatingSegment => '生成中…';

  @override
  String get generateThisSegment => '生成这一段';

  @override
  String get continueAction => '继续';

  @override
  String get scenePlaceholder => '场景';

  @override
  String get noBackgroundImage => '（无背景图，占位）';

  @override
  String backgroundLabel(String id) => '背景：$id';

  @override
  String get choosePlease => '请选择';

  @override
  String get segmentNotWritten => '这一站的过程还没写，点下方生成';

  @override
  String castWithSlot(String name, String slot) => '$name（$slot）';

  @override
  String get backToBottom => '回到底部';

  @override
  String get chooseModel => '选择模型';

  @override
  String get replyChoices => '回复选项';

  @override
  String get refreshChoices => '换一批';

  @override
  String get startChat => '开始对话';

  // Create assistant.

  @override
  String get assistantTitle => '创作助手';

  @override
  String get currentStory => '当前故事';

  @override
  String get notSelected => '未选择';

  @override
  String get pickStoryTitle => '选择故事';

  @override
  String get pickStoryHint => '点选故事';

  @override
  String get noStoriesYet => '还没有故事，先去故事页新建';

  @override
  String get assistantEmptyHint => '说说这段故事该怎么走';

  @override
  String get assistantComposerHint => '想写出怎样的情节…';

  @override
  String get assistantPending => '正在理顺走向…';

  @override
  String get assistantNeedsStory => '先在上面选一个故事，我才能读它的设定';

  @override
  String get assistantNeedsService => '先在设置里配好写故事的服务';

  @override
  String get assistantFailedRetry => '没写出来，换个说法再试';

  @override
  String get assistantFailedLater => '没写出来，稍后再试';

  @override
  String get assistantNoSave => '没能写进故事，稍后再试一次';

  @override
  String get assistantGraphSaved => '情节图写好了，可以在情节图里继续调整';

  @override
  String get proposalLead => '读了设定，理出';

  @override
  String stopCount(int count) => '$count 站';

  @override
  String branchCount(int count) => '$count 处岔路';

  @override
  String get generatedPlotTitle => '生成的情节';

  @override
  String get replaceGraph => '替换情节图';

  @override
  String get writeGraph => '写入情节图';

  @override
  String get skipWrite => '先不写';

  @override
  String replaceStops(int count) => '会替换现有的 $count 站';

  @override
  String replaceStopsWithBeats(int count, int beats) =>
      '会替换现有的 $count 站，$beats 段剧情一起清掉';

  // Saves tab.

  @override
  String get resumePlay => '继续游玩';

  @override
  String get openStory => '打开故事';

  @override
  String get deleteSave => '删除存档';

  @override
  String get deleteSavesTitle => '删除这些存档？';

  @override
  String get deleteSaveTitle => '删除这个存档？';

  @override
  String get deleteSaveDetail => '只清掉进度，故事本身还在';

  @override
  String get searchSavesHint => '搜索会话';

  @override
  String get exitSelection => '取消多选';

  @override
  String selectAll(bool allSelected) => allSelected ? '取消全选' : '全选';

  @override
  String get multiSelect => '多选';

  @override
  String get noSavesMessage => '还没有进行中的会话';

  @override
  String get noSavesDetail => '开玩视觉小说或聊天后会出现在这里';

  @override
  String get noMatchMessage => '没有匹配的会话';

  @override
  String get noMatchDetail => '换个关键词试试';

  @override
  String get goStories => '去故事';

  @override
  String get kindChat => '聊天';

  @override
  String get kindVisualNovel => '视觉小说';

  @override
  String lastPlayed(String kind, String relative) => '$kind · 上次游玩 $relative';

  @override
  String get justNow => '刚刚';

  @override
  String minutesAgo(int minutes) => '$minutes 分钟前';

  @override
  String hoursAgo(int hours) => '$hours 小时前';

  @override
  String daysAgo(int days) => '$days 天前';

  @override
  String loadFailed(Object error) => '加载失败：$error';

  @override
  String cannotResume(Object error) => '无法继续：$error';
}
