import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/domain/settings/ai_settings.dart';
import 'package:anoworld/domain/settings/appearance_settings.dart';
import 'package:anoworld/foundation/ai/st_prompt_manager.dart';
import 'package:anoworld/foundation/logging/app_log_level.dart';
import 'package:anoworld/foundation/theme/theme_tokens.dart';
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

  @override
  String get back => '返回';

  @override
  String get done => '完成';

  @override
  String get confirm => '确定';

  @override
  String get search => '搜索';

  @override
  String get searchFonts => '搜索字体';

  @override
  String get clear => '清除';

  @override
  String get copy => '复制';

  @override
  String get edit => '编辑';

  @override
  String get expand => '展开';

  @override
  String get collapse => '收起';

  @override
  String get remove => '移除';

  @override
  String get add => '添加';

  @override
  String get send => '发送';

  @override
  String get stop => '停止';

  @override
  String get inputMessage => '输入消息';

  @override
  String get thinking => '思考过程';

  @override
  String get emptyContent => '这里还没有内容';

  @override
  String get notFilled => '未填写';

  @override
  String get currentBadge => '当前';

  @override
  String get colorTitle => '颜色';

  @override
  String get entry => '条目';

  @override
  String copiedEntry(String label) => '已复制：$label';

  @override
  String moreEntries(int count) => '还有 $count 条';

  @override
  String get closePreview => '关闭预览';

  @override
  String get zoomHint => '双击缩放，点一下关闭';

  @override
  String get tidyLayout => '整理排版';

  @override
  String get addStation => '加一站';

  @override
  String get graphEmpty => '还没有情节站';

  @override
  String get fontSystemDefault => '系统默认';

  @override
  String get fontImported => '已导入';

  @override
  String get fontImportDone => '字体已导入到应用字体库';

  @override
  String get fontImportFailed => '无法导入该字体文件';

  @override
  String get fontRemoved => '已从应用字体库中移除';

  @override
  String get fontRemoveFailed => '无法删除该字体';

  @override
  String get fontPickFile => '选择字体文件…';

  @override
  String get fontLoading => '加载字体…';

  @override
  String get fontDeleteTitle => '删除字体？';

  @override
  String fontDeleteDetail(String family) => '从应用字体库中移除「$family」以释放空间？';

  @override
  String get fontRemoveAction => '从库中移除';

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
  String get tabMe => '设置';

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
  String get importAction => '导入';

  @override
  String get plotElementsHubHint => '全局库，给故事勾着用';

  @override
  String get aiPresetTitle => '预设';

  @override
  String get aiPresetHubHint => '输出风格、采样与提示词';

  @override
  String get selectPlayModeHint => '选一个入口看内容';

  @override
  String get noPersonaYet => '还没有身份';

  @override
  String get selectMeHint => '选一个身份或设置看详情';

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
  String get selectStoryHint => '选一个故事看详情';

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
  String get pickStoryPackTitle => '选择故事包';

  @override
  String get exportStoryPack => '导出故事包';

  @override
  String get exportStoryPackDialog => '导出故事包';

  @override
  String exportedStory(String title) => '已导出「$title」';

  @override
  String exportFailed(Object error) => '导出失败：$error';

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
  String get deleteStoryDetail => '故事、存档和创作助手的对话都会删掉';

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
  String get renameStory => '改故事名';

  @override
  String get storyNameHint => '故事名称';

  @override
  String renameStoryFailed(Object error) => '改名失败：$error';

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

  @override
  String get visualStageTitle => '画面';

  @override
  String visualSize(int portraits, int scenes) {
    if (portraits == 0 && scenes == 0) return '还没有立绘和场景图';
    return '$portraits 张立绘，$scenes 张场景图';
  }

  @override
  String get visualStageWritePrompts => '一键生成提示词';

  @override
  String get visualStageGenerateImages => '一键生成图片';

  @override
  String get visualStageStyleSection => '画风';

  @override
  String get visualStagePortraitSection => '角色立绘';

  @override
  String get visualStageSceneSection => '场景图';

  @override
  String get visualStageNeedCast => '先准备好角色';

  @override
  String get visualStageNeedNodes => '先准备好情节站';

  @override
  String get visualStageNeedComfy => '先在设置里选好生图服务，填好地址';

  @override
  String get visualStageNeedPrompts => '先生成提示词，再出图';

  @override
  String get visualStagePromptsSaved => '提示词已保存';

  @override
  String get visualStageImagesDone => '图片已写入故事';

  @override
  String get visualStageStylePrefix => '画风前缀';

  @override
  String get visualStageNegative => '负面提示词';

  @override
  String get visualStageFacing => '立绘朝向';

  @override
  String get visualStageFacingLeft => '面向左 · 站右边';

  @override
  String get visualStageFacingRight => '面向右 · 站左边';

  @override
  String get visualStageNoPrompt => '还没有提示词';

  @override
  String get visualPromptLabel => '提示词';

  @override
  String get visualPromptSaveFailed => '提示词没保存上，再试一次';

  @override
  String get visualPromptRegen => '重新生成提示词';

  @override
  String get visualPromptRegenDone => '提示词已更新';

  @override
  String get visualImageRegen => '重新生成图片';

  @override
  String get visualImageRegenDone => '图片已更新';

  @override
  String get visualStageBusyPrompts => '正在写提示词…';

  @override
  String get visualStageBusyImages => '正在出图…';

  @override
  String get visualJobAlreadyRunning => '还有图片在画，画完再来';

  @override
  String get visualRegenPortrait => '重新画立绘';

  @override
  String get visualRegenScene => '重新画场景';

  @override
  String get visualRegenBusy => '正在重画…';

  @override
  String get visualRegenDone => '已更新画面';

  @override
  String get visualNoPortrait => '还没有立绘';

  @override
  String get visualNoScene => '还没有场景图';

  @override
  String get visualNeedPortraitTags => '先在「画面」里写好角色长相标签';

  @override
  String get visualNeedComfyShort => '请先在设置里配好生图';

  @override
  String get accept => '采用';

  @override
  String get regenerate => '重来';

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
  String get statusStopped => '已停止生成';

  @override
  String get statusSafeExit => '用稳妥出口继续';

  @override
  String get fallbackBeatText => '这一段暂时写不出来，可以先用下方选项继续';

  @override
  String gotoNode(String name) => '前往：$name';

  @override
  String get regenerateReply => '重新生成回复';

  @override
  String get regenerateSegment => '重新生成';

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
  String get historyBack => '后退';

  @override
  String get historyForward => '前进';

  @override
  String get historyFastForward => '快进';

  @override
  String get vnSettingsTitle => '游玩设置';

  @override
  String get dialogueBoxSection => '对话框';

  @override
  String get dialogueBoxHint => '高度固定，超出的文字翻到下一页';

  @override
  String get dialogueLines => '行数';

  @override
  String dialogueLinesValue(int lines) => '$lines 行';

  @override
  String get dialogueTextSpeed => '文字速度';

  @override
  String dialogueTextSpeedValue(int charsPerSecond) =>
      charsPerSecond <= 0 ? '瞬间' : '每秒 $charsPerSecond 字';

  @override
  String get dialogueFontSize => '字号';

  @override
  String dialogueFontSizeValue(double size) => size.round().toString();

  @override
  String get dialogueColorsSection => '颜色';

  @override
  String get dialogueBackground => '背景颜色';

  @override
  String get dialogueFollowTheme => '跟随主题';

  @override
  String get dialogueBackgroundTheme => '背景跟随主题';

  @override
  String get dialogueBackgroundThemeHint => '取当前主题的底色，配上半透明与模糊';

  @override
  String get dialogueText => '文字颜色';

  @override
  String get dialogueTextTheme => '文字跟随主题';

  @override
  String get dialogueTextThemeHint => '用主题里的正文颜色';

  @override
  String get dialogueOpacity => '不透明度';

  @override
  String dialogueOpacityValue(int percent) => '$percent%';

  @override
  String get imageGenQualitySection => '生图质量';

  @override
  String get imageGenQualityHint =>
      '可选手动宽高或预设（含 16:9）；越小越快，超分更清晰但更慢';

  @override
  String get imageGenStepsLabel => '采样步数';

  @override
  String imageGenStepsValue(int steps) => '$steps 步';

  @override
  String get imageGenPortraitSizeLabel => '立绘尺寸';

  @override
  String get imageGenSceneSizeLabel => '场景尺寸';

  @override
  String get imageGenWidthLabel => '宽度';

  @override
  String get imageGenHeightLabel => '高度';

  @override
  String get imageGenSizePresetLabel => '尺寸预设';

  @override
  String imageGenSizePresetValue(ImageGenSizePreset preset) =>
      '${preset.aspectLabel} · ${preset.sizeLabel}';

  @override
  String imageGenSizeValue(int width, int height) => '$width×$height';

  @override
  String get imageGenUpscaleLabel => '出图后超分';

  @override
  String get imageGenUpscaleHint => '放大立绘与场景，耗时更长';

  @override
  String get vnDirectionSection => '视觉小说演出';

  @override
  String get vnDirectionHint => '每段对白多长、站内要不要出选项、情节图至少几站，都在这里调';

  @override
  String get vnMinLinesLabel => '每段最少句数';

  @override
  String vnMinLinesValue(int lines) => '$lines 句';

  @override
  String get minGraphStationsLabel => '情节图最少站数';

  @override
  String minGraphStationsValue(int stations) => '$stations 站';

  @override
  String get vnInStationChoicesLabel => '站内选项';

  @override
  String get vnInStationChoicesHint => '出站分叉始终有选项；这里只影响站内续写要不要弹选项';

  @override
  String vnInStationChoiceFrequencyName(Object frequency) {
    final name = frequency is Enum ? frequency.name : '$frequency';
    return switch (name) {
      'off' => '关闭',
      'rare' => '很少',
      'sometimes' => '有时',
      'often' => '较多',
      _ => '很少',
    };
  }

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
  String get chooseModelHint => '写对白与剧情用';

  @override
  String get backAction => '返回';

  @override
  String get replyChoices => '回复选项';

  @override
  String get refreshChoices => '换一批';

  @override
  String get startChat => '开始对话';

  // Story editors.

  @override
  String get titleLabel => '标题';

  @override
  String get bodyLabel => '正文';

  @override
  String get undoAction => '撤销';

  @override
  String get redoAction => '重做';

  @override
  String get createEntrySection => '创作入口';

  @override
  String get createEntryBlurbCard => '导入角色卡，填入设定与角色';

  @override
  String get createEntryBlurbNovel => '粘贴剧情，拆成可玩内容';

  @override
  String get createEntryBlurbStaged => '按世界 → 人物 → 走向逐步填写';

  @override
  String get createEntryComingSoon => '这条创作路径马上就好';

  @override
  String get createEntryComingSoonDetail => '可先导入角色卡或用分阶段提示词';

  @override
  String get worldBookNoKeywords => '按需 · 还没写关键词';

  @override
  String worldBookKeywords(String keywords) => '按需 · $keywords';

  @override
  String get worldBookSelectEntries => '选择条目';

  @override
  String worldBookSelectedCount(int count) => '已选 $count 条';

  @override
  String get worldBookSelectAll => '全选';

  @override
  String get worldBookDeselectAll => '取消全选';

  @override
  String get worldBookAddEntry => '加一条设定';

  @override
  String get worldBookOpenFailed => '无法打开设定';

  @override
  String get worldBookSectionHint => '常驻会一直带上；其他条目靠关键词唤起';

  @override
  String get worldBookEntriesSection => '设定条目';

  @override
  String get worldBookEmptyDetail => '先写世界基调，再补地名与规则';

  @override
  String get worldBookUnnamedEntry => '未命名设定';

  @override
  String get worldBookNewEntry => '新设定';

  @override
  String get worldBookEditEntry => '编辑设定';

  @override
  String get worldBookTitleHint => '世界观、客栈、城门规则…';

  @override
  String get worldBookBodyHint => '写给故事用的完整说明，单独成段也能读懂';

  @override
  String get worldBookAlwaysOn => '始终带上';

  @override
  String get worldBookAlwaysOnHint => '基调、硬规则适合打开';

  @override
  String get worldBookKeywordsHint => '用顿号或逗号分开，聊到这些词时才会带上这条';

  @override
  String get worldBookDeleteOneTitle => '删除这条设定？';

  @override
  String worldBookDeleteManyTitle(int count) => '删除这 $count 条设定？';

  @override
  String get worldBookDeleteDetail => '删掉后无法恢复';

  @override
  String get castAddMember => '加一个角色';

  @override
  String get castAddOne => '加一个';

  @override
  String get castOpenFailed => '无法打开角色';

  @override
  String get castSection => '登场人物';

  @override
  String get castSectionHint => '可勾选一名主角，作为酒馆里的当前角色';

  @override
  String get castEmptyDetail => '先加主角和关键配角';

  @override
  String get castNoSummary => '还没写简介';

  @override
  String castProtagonist(String summary) => '主角 · $summary';

  @override
  String get castNewMember => '新角色';

  @override
  String get castEditMember => '编辑角色';

  @override
  String get castNameLabel => '名字';

  @override
  String get castSummaryLabel => '简介';

  @override
  String get castPersonalityLabel => '性格';

  @override
  String get castSpeechLabel => '说话方式';

  @override
  String get castExamplesLabel => '示例对白';

  @override
  String get castExamplesHint => '一行一句';

  @override
  String get castProtagonistLabel => '主角';

  @override
  String get castProtagonistHint => '酒馆里「当前角色」的名字与设定来源';

  // ---- Play role / cast extraction ----

  @override
  String get playRoleTitle => '你扮演谁';

  @override
  String get playRoleHint => '本局固定，开始后不能更改';

  @override
  String get castExtractEntry => '从世界书提取';

  @override
  String get castExtractTitle => '从世界书提取角色';

  @override
  String get castExtractIntro => '扫一遍世界书，把散落的角色整理成角色卡';

  @override
  String get castExtractRunning => '正在读世界书';

  @override
  String get castExtractEmpty => '世界书里没找到角色';

  @override
  String get castExtractEmptyDetail => '先在设定里写好人物条目，再来提取';

  @override
  String get castExtractFailed => '没能完成，请再试一次';

  @override
  String get castExtractExisting => '已有，只补空字段';

  @override
  String get castExtractNew => '新角色';

  @override
  String get castExtractApply => '写入角色';

  @override
  String get castExtractGoVisual => '去生成立绘';

  @override
  String get castAliasesLabel => '别名';

  @override
  String castExtractDone(int count) => '已加入 $count 名角色';

  @override
  String castExtractDiscarded(int count) => '有 $count 处与原文对不上，已跳过';

  @override
  String get castDeleteMember => '删除这个角色';

  @override
  String get castUnnamedMember => '未命名角色';

  @override
  String get mainGraphCanvas => '画布';

  @override
  String get mainGraphCard => '卡片';

  @override
  String get mainGraphOverview => '全图';

  @override
  String get mainGraphScene => '场景';

  @override
  String get mainGraphMenuSection => '画布';

  @override
  String get mainGraphShowGrid => '显示网格';

  @override
  String get mainGraphShowGridHint => '缩放时自动调整间距';

  @override
  String get mainGraphInputPort => '进入';

  @override
  String get mainGraphBranchLabel => '岔路';

  @override
  String get mainGraphContinueLabel => '继续';

  @override
  String get mainGraphNewNodeTitle => '新情节';

  @override
  String get mainGraphNewNodeSynopsis => '写清这一站要发生什么';

  @override
  String get mainGraphDeleteNodeTitle => '删除这一站？';

  @override
  String mainGraphDeleteNodeDetail(String title) => '「$title」和连到它的线都会去掉';

  @override
  String get mainGraphDeleteNodeDetailEmpty => '连到它的线也会一起去掉';

  @override
  String mainGraphLeadsTo(String title) => '通向$title';

  @override
  String get mainGraphNodeSheetTitle => '这一站';

  @override
  String get mainGraphNodeGoalLabel => '本站目标';

  @override
  String get mainGraphNodeKindLabel => '种类';

  @override
  String get mainGraphOutgoingLabel => '连出去';

  @override
  String get mainGraphNoOutgoing => '还没有连线：从右侧插头拖到下一站左侧';

  @override
  String get nodeKindOpening => '开场';

  @override
  String get nodeKindScene => '过程';

  @override
  String get nodeKindTurning => '转折';

  @override
  String get nodeKindEnding => '结束';

  @override
  String get mainGraphDeleteNodeAction => '删除这一站';

  @override
  String get mainGraphEdgeSheetTitle => '这条路';

  @override
  String get mainGraphEdgeDetailLabel => '详细说明';

  @override
  String get mainGraphEdgeDetailHint => '可以只写关键词，再让 AI 帮你展开';

  @override
  String get mainGraphEdgeWriting => '正在写…';

  @override
  String get mainGraphExpandWithAi => '让 AI 写详细一点';

  @override
  String get mainGraphDeleteEdge => '删掉这条连线';

  @override
  String get mainGraphExpandFailed => '没写出来，请稍后再试';

  @override
  String get mainGraphConnectTip => '拖到下一站左侧插头，就能连上';

  @override
  String get mainGraphOverviewTitle => '走向全览';

  @override
  String get mainGraphOverviewHint => '滑动地图移动镜头，点外侧或拖标题收起';

  @override
  String get mainGraphOpenFailed => '打不开情节图';

  @override
  String get mainGraphGenerate => '一键生成情节';

  @override
  String get mainGraphGenerateFailed => '没生成出来，稍后再试';

  @override
  String get noStory => '没有故事';

  @override
  String get cardImportSection => '从酒馆卡摘素材';

  @override
  String get cardImportSectionHint => '只取设定与角色，不跑插件和正则';

  @override
  String get cardPickCards => '选择角色卡';

  @override
  String get cardRepick => '重新选卡';

  @override
  String get cardPickHint => '可选多张：第一张作主角与故事名，其余当配角';

  @override
  String get cardReading => '读取中…';

  @override
  String get cardEmptyTitle => '还没有读入角色卡';

  @override
  String get cardEmptyDetail => '支持 .json 与带角色数据的 .png';

  @override
  String get cardStoryNameLabel => '故事名';

  @override
  String get cardTidySection => '整理';

  @override
  String get cardTidyHint => '去掉网页标记，保留 Markdown';

  @override
  String get cardSanitize => '清理格式';

  @override
  String get cardCastSection => '角色';

  @override
  String get cardCastSectionHint => '描述、性格与示例对白';

  @override
  String get cardWorldBookSection => '世界书';

  @override
  String get cardWorldBookSectionHint => '情景、开场素材与角色书条目；卡里关闭的默认不勾';

  @override
  String get cardNoWorldBookEntries => '这张卡没有可摘的设定条目';

  @override
  String get cardAiNoteSection => '卡内 AI 说明';

  @override
  String get cardAiNoteHint => '不会写进故事，写对白请在设置里改 AI 预设';

  @override
  String get cardWrite => '写入故事';

  @override
  String get cardWriteHint => '写入后可在创作里继续改设定、角色与情节';

  @override
  String get cardCoverHint => '会一起保存为故事封面';

  @override
  String get cardCoverMissing => '这张卡没有封面图，可在故事页更换';

  @override
  String get cardInfoTitle => '卡片信息';

  @override
  String get cardInfoCreator => '作者';

  @override
  String get cardInfoVersion => '版本';

  @override
  String get cardInfoTags => '标签';

  @override
  String get cardInfoCreatorNotes => '作者注';

  @override
  String get cardInfoEmpty => '作者、版本、标签都空着，点这里补上';

  @override
  String get cardInfoEditTitle => '编辑卡片信息';

  @override
  String get cardInfoTagsHint => '多个标签用逗号分开';

  @override
  String get cardInfoCreatorNotesHint => '原作者留下的说明';

  @override
  String cardInfoTagCount(int count) => '$count 个标签';

  @override
  String cardReadCount(int count) => '已读入 $count 张卡，可勾选要留下的内容';

  @override
  String get cardSanitizeNoChange => '格式已是 Markdown，无需再清';

  @override
  String cardSanitizeChanged(int count) => '已调整 $count 处排版';

  @override
  String get cardNeedOneCast => '至少留下一个角色';

  @override
  String get cardReadUnavailable => '无法读取所选文件，请完全退出应用后重开再试';

  @override
  String cardReadFailed(Object error) => '读卡失败：$error';

  @override
  String cardWriteFailed(Object error) => '写入失败：$error';

  @override
  String cardCannotRead(String file) => '无法读取 $file';

  @override
  String cardUnsupportedFormat(String extension) =>
      '暂只支持 .json / .png（$extension）';

  @override
  String get stagedWorld => '世界';

  @override
  String get stagedCast => '人物';

  @override
  String get stagedMain => '走向';

  @override
  String get stagedWorldHint => '例如：雨夜的边城，人们靠传闻活着';

  @override
  String get stagedCastHint => '例如：少年想离开，客栈老板知道出路';

  @override
  String get stagedMainHint => '例如：今晚必须出城，在客栈做一个选择';

  @override
  String get stagedWorldPrompt => '写一两句世界';

  @override
  String get stagedCastPrompt => '写一两句人物';

  @override
  String get stagedMainPrompt => '写一两句走向';

  @override
  String get stagedNeedPrompt => '先写一两句提示';

  @override
  String get stagedNeedService => '请先在设置里配好写故事的服务';

  @override
  String get stagedGenerating => '正在生成…';

  @override
  String get stagedNeedWorldFirst => '请先完成世界设定';

  @override
  String get stagedNeedWorldAndCast => '请先完成设定和角色';

  @override
  String get stagedNeedWorldDone => '请先生成设定';

  @override
  String get stagedNeedCastDone => '请先生成角色';

  @override
  String get stagedNeedMainDone => '请先生成走向';

  @override
  String get stagedGenerateFailed => '生成失败，请稍后重试';

  @override
  String createStoryFailed(Object error) => '创建故事失败：$error';

  @override
  String get stagedBooting => '正在准备故事…';

  @override
  String get stagedGenerate => '生成';

  @override
  String get stagedRegenerate => '重写这一阶段';

  @override
  String get stagedGeneratingShort => '生成中…';

  @override
  String get stagedPreviewLabel => '预览（可改）';

  @override
  String get stagedPlay => '开始游玩';

  @override
  String get stagedNext => '下一步';

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
  String get assistantEmptyHint => '先选改哪一块，再说想怎么改';

  @override
  String get assistantComposerHint => '想怎么改…';

  @override
  String get assistantPending => '正在整理…';

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
  String get assistantWorldSaved => '设定写好了，可以在世界书里继续调整';

  @override
  String get assistantCastSaved => '角色写好了，可以在角色页继续调整';

  @override
  String get assistantPlotSaved => '剧情元素变了，之后的生成会按新的来';

  @override
  String assistantLayersSaved(String layers) => '写好了，$layers一起更新了';

  @override
  String get proposalLead => '读了设定，理出';

  @override
  String stopCount(int count) => '$count 站';

  @override
  String branchCount(int count) => '$count 处岔路';

  @override
  String get assistantTargetGraph => '情节图';

  @override
  String get assistantTargetWorld => '世界书';

  @override
  String get assistantTargetCast => '角色';

  @override
  String opCount(int count) => '$count 处改动';

  @override
  String get patchReviewTitle => '这次要改这些';

  @override
  String applySelectedCount(int count) => '写入选中的 $count 条';

  @override
  String get patchNoChange => '没有实际改动';

  @override
  String get patchOpFailed => '这一步没法写入';

  @override
  String get patchEmptyValue => '（空）';

  @override
  String get patchTrueValue => '是';

  @override
  String get patchFalseValue => '否';

  @override
  String get patchOpAdded => '新增';

  @override
  String get patchOpEdited => '修改';

  @override
  String get patchOpRemoved => '删除';

  @override
  String get patchKindWorldBook => '设定';

  @override
  String get patchKindCast => '角色';

  @override
  String get patchKindNode => '情节站';

  @override
  String get patchKindEdge => '连线';

  @override
  String get patchKindStorySummary => '主线概括';

  @override
  String get patchKindPlotElement => '剧情元素';

  @override
  String get patchBeforeLabel => '原';

  @override
  String get patchAfterLabel => '改';

  @override
  String patchFieldLabel(String field) => switch (field) {
        'title' => '标题',
        'body' => '正文',
        'keys' => '关键词',
        'alwaysOn' => '常驻',
        'name' => '名字',
        'summary' => '简介',
        'personality' => '性格',
        'speechStyle' => '口吻',
        'exampleLines' => '例句',
        'isProtagonist' => '主角',
        'synopsis' => '目标',
        'tags' => '标签',
        'from' => '起点',
        'to' => '终点',
        'kind' => '类型',
        'label' => '标注',
        'detail' => '说明',
        'storySummary' => '主线概括',
        'keyword' => '关键词',
        'category' => '分类',
        'description' => '说明',
        'selected' => '已选',
        _ => field,
      };

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
  String get selectSaveHint => '选一条存档看详情';

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

  // Settings shell.

  @override
  String get settingsSectionGeneral => '通用';

  @override
  String get settingsSectionAppearance => '外观';

  @override
  String get settingsSectionAi => 'AI 配置';

  @override
  String get settingsSectionGeneration => '生成设置';

  @override
  String get settingsSectionAbout => '关于';

  @override
  String get settingsSectionGeneralHint => '其它选项';

  @override
  String get settingsSectionAppearanceHint => '主题、字体与圆角';

  @override
  String get settingsSectionAiHint => '服务地址、密钥与模型';

  @override
  String get settingsSectionGenerationHint => '出图质量与演出';

  @override
  String get settingsSectionAboutHint => '版本与说明';

  @override
  String get settingsNothingToChange => '这里还没有可改的选项';

  @override
  String get advancedTitle => '高级';

  @override
  String get advancedHint => '诊断日志等开发选项';

  @override
  String get diagnosticsSection => '诊断';

  @override
  String get diagnosticsHint => '供开发排查，正式版不显示本页';

  @override
  String get diagnosticsLogTitle => '诊断日志';

  @override
  String get logsEmpty => '暂无日志';

  @override
  String get clearAction => '清空';

  @override
  String logCount(int count) => '共 $count 条';

  @override
  String get logNone => '暂无记录';

  @override
  String get copiedToast => '已复制';

  @override
  String logLevelName(AppLogLevel level) => switch (level) {
        AppLogLevel.info => '信息',
        AppLogLevel.warning => '警告',
        AppLogLevel.error => '错误',
      };

  // About.

  @override
  String get appTagline => '视觉小说创作器 + 运行时';

  @override
  String get appDescription =>
      '本地配置文本与生图 AI，结构化创作剧本，用聊天式或视觉小说式双模式验本与游玩。'
      'SillyTavern 角色卡仅作素材入口，不是兼容目标';

  @override
  String appVersion(String version) => '版本 $version';

  // Appearance.

  @override
  String get themeSection => '主题';

  @override
  String get themeModeLabel => '主题模式';

  @override
  String get themeModeHint => '跟随系统、浅色或深色';

  @override
  String get themeColorLabel => '主题颜色';

  @override
  String get themeColorHint => '浅色与深色各记一套';

  @override
  String get customColorsLabel => '自定义颜色';

  @override
  String get customColorsHint => '调整当前配色';

  @override
  String get interfaceSection => '界面';

  @override
  String get fontLabel => '字体';

  @override
  String get fontHint => '系统字体或导入文件';

  @override
  String get fontSizeLabel => '字体大小';

  @override
  String get cornerRadiusLabel => '圆角大小';

  @override
  String get currentTag => '当前';

  @override
  String get inUseTag => '使用中';

  @override
  String get lightSlotTag => '亮色';

  @override
  String get darkSlotTag => '暗色';

  @override
  String get customTag => '自定义';

  @override
  String get manageAction => '管理';

  @override
  String get copyAction => '复制';

  @override
  String get saveAsTheme => '保存为主题';

  @override
  String get restoreDefaults => '恢复默认';

  @override
  String get saveAsThemeTitle => '保存为主题颜色';

  @override
  String defaultThemeName(int number) => '主题 $number';

  @override
  String get themeNameLabel => '主题名称';

  @override
  String copyName(String name) => '$name 副本';

  @override
  String get renameThemeTitle => '重命名主题';

  @override
  String get deleteThemeTitle => '删除主题？';

  @override
  String deleteThemeDetail(String name) => '删除「$name」后无法恢复';

  @override
  String themeModeName(AppThemeModeSetting mode) => switch (mode) {
        AppThemeModeSetting.system => '跟随系统',
        AppThemeModeSetting.light => '浅色',
        AppThemeModeSetting.dark => '深色',
      };

  @override
  String themePresetName(ThemePreset preset) => switch (preset) {
        ThemePreset.light => '浅色',
        ThemePreset.grey => '灰色',
        ThemePreset.slate => '石板',
        ThemePreset.claude => 'Claude Code',
        ThemePreset.mint => '薄荷',
        ThemePreset.purple => '紫色',
        ThemePreset.hermes => 'Hermes',
        ThemePreset.ocean => '海洋',
        ThemePreset.darkModern => '深色现代',
        ThemePreset.graphite => '石墨',
        ThemePreset.forest => '深林',
        ThemePreset.espresso => '咖啡',
        ThemePreset.midnight => '午夜',
        ThemePreset.dusk => '暮色',
        ThemePreset.cursorDark => 'Cursor 深色',
      };

  @override
  String themeTokenName(ThemeToken token) => switch (token) {
        ThemeToken.editorSurface => '应用背景',
        ThemeToken.sidebarSurface => '面板背景',
        ThemeToken.controlSurface => '按钮和输入框',
        ThemeToken.border => '边框',
        ThemeToken.divider => '分割线',
        ThemeToken.primaryText => '主文字',
        ThemeToken.mutedText => '次要文字',
        ThemeToken.accent => '强调色',
        ThemeToken.secondaryAccent => '次要强调色',
        ThemeToken.tertiaryAccent => '辅助强调色',
        ThemeToken.cursor => '光标',
        ThemeToken.chatBackground => '聊天背景',
        ThemeToken.characterBubble => '角色气泡',
        ThemeToken.userBubble => '我的气泡',
        ThemeToken.chatText => '消息文字',
        ThemeToken.dialogueText => '对白文字',
      };

  @override
  String themeTokenHint(ThemeToken token) => switch (token) {
        ThemeToken.editorSurface => '窗口底色',
        ThemeToken.sidebarSurface => '侧栏与弹层',
        ThemeToken.controlSurface => '按钮、菜单、输入框',
        ThemeToken.border => '控件描边',
        ThemeToken.divider => '列表分隔线',
        ThemeToken.primaryText => '标题与正文',
        ThemeToken.mutedText => '提示与说明',
        ThemeToken.accent => '选中与高亮',
        ThemeToken.secondaryAccent => '第二强调',
        ThemeToken.tertiaryAccent => '第三强调',
        ThemeToken.cursor => '输入光标',
        ThemeToken.chatBackground => '聊天页底色',
        ThemeToken.characterBubble => '角色气泡',
        ThemeToken.userBubble => '我的气泡',
        ThemeToken.chatText => '叙述文字',
        ThemeToken.dialogueText => '引号对白',
      };

  // AI channels.

  @override
  String get textChannelTitle => '文本 AI';

  @override
  String get textChannelHint => '写对白与剧情';

  @override
  String get imageChannelTitle => '生图 AI';

  @override
  String get imageChannelHint => '生成插画，与文本分开';

  @override
  String get pickProviderTitle => '选择供应商';

  @override
  String get pickProviderHint => '写故事与生图请分开选择';

  @override
  String get currentProvider => '当前服务商';

  @override
  String get changeAction => '更换';

  @override
  String get baseUrlLabel => '服务地址';

  @override
  String get baseUrlHint => '接口根地址';

  @override
  String get baseUrlEmpty => '未填写';

  @override
  String get apiKeyLabel => '密钥';

  @override
  String get apiKeyHint => '访问服务用';

  @override
  String get modelLabel => '模型';

  @override
  String get tapToChoose => '点这里选择';

  @override
  String get probingShort => '正在查找…';

  @override
  String get modelNotChosen => '未选择';

  @override
  String get modelHintNone => '点这里选择，或先查找可用模型';

  @override
  String foundModelsShort(int count) => '已找到 $count 个';

  @override
  String get reasoningLabel => '思考程度';

  @override
  String get reasoningHint => '影响会想多久再回答';

  @override
  String get probeModels => '查找模型';

  @override
  String get probeModelsRunning => '正在查找模型';

  @override
  String get probeModelsHint => '重新拉取可用列表';

  @override
  String get probeHintNeedsKey => '填好服务地址和密钥后，会自动查找可用模型';

  @override
  String get probeHintNoKey => '填好服务地址后，会自动查找可用模型';

  @override
  String get probeHintManual =>
      '请手动填写模型，或点「查找模型」。ComfyUI 会列出本机 checkpoints';

  @override
  String get probingModels => '正在查找可用模型…';

  @override
  String foundModels(int count) => '找到 $count 个可用模型';

  @override
  String get probeFallbackModels => '暂时连不上服务，已改用常用模型列表';

  @override
  String probeFailed(Object error) => '查找失败：$error';

  @override
  String textProviderName(AiTextProviderKind kind) => switch (kind) {
        AiTextProviderKind.openAiCompatible => '自定义',
        AiTextProviderKind.openai => 'OpenAI',
        AiTextProviderKind.deepSeek => 'DeepSeek',
        AiTextProviderKind.openRouter => 'OpenRouter',
        AiTextProviderKind.qwen => '通义千问',
        AiTextProviderKind.siliconFlow => '硅基流动',
        AiTextProviderKind.moonshot => 'Moonshot',
        AiTextProviderKind.zai => '智谱',
        AiTextProviderKind.miniMax => 'MiniMax',
        AiTextProviderKind.ollama => 'Ollama',
      };

  @override
  String imageProviderName(AiImageProviderKind kind) => switch (kind) {
        AiImageProviderKind.openAiCompatible => '自定义 / 生图',
        AiImageProviderKind.openai => 'OpenAI Images',
        AiImageProviderKind.openaiChat => '对话生图',
        AiImageProviderKind.siliconFlow => '硅基流动',
        AiImageProviderKind.pollinations => 'Pollinations（免费）',
        AiImageProviderKind.novelai => 'NovelAI',
        AiImageProviderKind.automatic1111 => 'Automatic1111',
        AiImageProviderKind.comfyui => 'ComfyUI',
      };

  @override
  String reasoningEffortName(AiReasoningEffort effort) => switch (effort) {
        AiReasoningEffort.auto => '自动',
        AiReasoningEffort.min => '最低',
        AiReasoningEffort.low => '低',
        AiReasoningEffort.medium => '中',
        AiReasoningEffort.high => '高',
        AiReasoningEffort.max => '最高',
      };

  // AI preset.

  @override
  String get presetRowHint => '控制输出风格和边界';

  @override
  String get pickPresetTitle => '选择预设';

  @override
  String get pickPresetHint => '内置或已导入的自定义';

  @override
  String get presetBuiltInGroup => '内置';

  @override
  String get presetMineGroup => '我的';

  @override
  String get presetNotChosen => '尚未选用';

  @override
  String presetApplied(String name) => '已套用：$name';

  @override
  String get presetNewAction => '新建预设';

  @override
  String get presetSaveCurrentAction => '保存当前设置为预设';

  @override
  String get presetRenameAction => '重命名当前预设';

  @override
  String get presetDeleteAction => '删除当前预设';

  @override
  String get presetImportAction => '导入预设';

  @override
  String get presetExportAction => '导出预设';

  @override
  String get presetNewName => '新预设';

  @override
  String presetCreated(String name) => '已新建：$name';

  @override
  String get presetRenameTitle => '重命名预设';

  @override
  String presetRenamed(String name) => '已改名：$name';

  @override
  String get presetRenameBuiltInHint => '内置预设不能改名，先保存为自己的';

  @override
  String presetDeleteTitle(String name) => '删除「$name」？';

  @override
  String get presetDeleteDetail => '只删这套预设，故事和当前设置不受影响';

  @override
  String get presetDeleteBuiltInHint => '内置预设不能删除';

  @override
  String get presetNoActive => '还没有选用预设';

  @override
  String get presetRestoreOrderAction => '恢复默认顺序';

  @override
  String get presetOrderRestored => '已恢复默认顺序';

  @override
  String get myPresetName => '我的预设';

  @override
  String presetSaved(String name) => '已保存：$name';

  @override
  String get presetDeleted => '已删除';

  @override
  String get invalidPresetFile => '不是合法的预设文件';

  @override
  String presetImported(String name) => '已导入并套用：$name';

  @override
  String presetImportFailed(Object error) => '导入失败：$error';

  @override
  String get exportPresetDialog => '导出预设';

  @override
  String get confirmAction => '确定';

  @override
  String get samplingSection => '采样';

  @override
  String get presetPromptsSection => '预设提示词';

  @override
  String get presetDefaultName => '均衡';

  @override
  String get presetCreativeName => '更发散';

  @override
  String get presetPreciseName => '更克制';

  @override
  String get presetDeterministicName => '更稳定';

  @override
  String get presetLongformName => '偏长篇';

  @override
  String get presetMirostatName => 'Mirostat 采样';

  @override
  String get presetDefaultHint => '日常写故事';

  @override
  String get presetCreativeHint => '想象力更大胆';

  @override
  String get presetPreciseHint => '少跑题、少废话';

  @override
  String get presetDeterministicHint => '同样输入更接近同样结果';

  @override
  String get presetLongformHint => '单次输出可以更长';

  @override
  String get presetMirostatHint => '按 Mirostat 调随机性';

  // Sampling.

  @override
  String get maxOutputLabel => '单次最长输出';

  @override
  String get contextLengthLabel => '上下文长度';

  @override
  String get temperatureLabel => '温度';

  @override
  String get streamOutput => '流式输出';

  @override
  String get streamOutputHint => '边生成边返回';

  @override
  String get advancedSampling => '高级采样';

  @override
  String get advancedSamplingHint => 'Top K、惩罚、Mirostat 等';

  @override
  String get advancedSamplingTitle => '高级采样';

  @override
  String get repetitionPenalty => '重复惩罚';

  @override
  String get penaltyRange => '惩罚范围';

  @override
  String get frequencyPenalty => '频率惩罚';

  @override
  String get presencePenalty => '存在惩罚';

  @override
  String get mirostatMode => 'Mirostat 模式';

  @override
  String get randomSeed => '随机种子';

  @override
  String get randomSeedHint => '-1 表示每次随机';

  @override
  String get stopSequences => '停止序列';

  @override
  String get stopSequencesHint => '每行一条';

  @override
  String get notSet => '未设置';

  // Prompt sections.

  @override
  String get promptSectionsTitle => '提示词分段';

  @override
  String get contentLabel => '内容';

  @override
  String get tapToEdit => '点按编辑文案';

  @override
  String get tapToView => '点按查看';

  @override
  String get filledByCast => '内容由当前故事角色填充';

  @override
  String get filledByCastReadOnly => '内容由当前故事角色填充，这里不能改';

  @override
  String get filledByPersona => '写故事时用当前玩家身份填充';

  @override
  String get filledByWorldBook => '写故事时用当前故事的世界书填充';

  @override
  String get filledByHistory => '写故事时自动带上对话历史';

  @override
  String get emptyAuthorNote => '暂无作者备注';

  @override
  String get filledAutomatically => '这段会在写故事时自动带上';

  @override
  String get promptAddTitle => '新建提示词';

  @override
  String get promptAddNameHint => '比如「少用书面语」';

  @override
  String promptAdded(String name) => '已添加：$name';

  @override
  String promptDeleteTitle(String name) => '删除「$name」？';

  @override
  String get promptDeleteDetail => '删掉后不能恢复';

  @override
  String get promptDeleteBuiltInHint => '内置提示词不能删除';

  @override
  String get promptDeleted => '已删除';

  @override
  String promptSectionName(PromptSectionType type) => switch (type) {
        PromptSectionType.systemPrompt => '系统提示',
        PromptSectionType.persona => '玩家身份',
        PromptSectionType.characterDescription => '角色描述',
        PromptSectionType.characterPersonality => '角色性格',
        PromptSectionType.characterScenario => '场景',
        PromptSectionType.exampleMessages => '示例对白',
        PromptSectionType.worldInfo => '设定（前）',
        PromptSectionType.worldInfoAfter => '设定（后）',
        PromptSectionType.authorNote => '作者备注',
        PromptSectionType.postHistoryInstructions => '历史后指令',
        PromptSectionType.nsfw => '成人向提示',
        PromptSectionType.chatHistory => '对话历史',
        PromptSectionType.enhanceDefinitions => '强化定义',
        PromptSectionType.custom => '自定义',
      };

  // Player persona.

  @override
  String get personaTitle => '玩家身份';

  @override
  String get addPersona => '添加身份';

  @override
  String get personasEmpty => '还没有身份';

  @override
  String get personasEmptyHint => '添加一套，写故事和游玩时会用到';

  @override
  String deletePersonaTitle(String name) => '删除「$name」？';

  @override
  String get deletePersonaHint => '删掉后不能恢复';

  @override
  String get editPersona => '编辑身份';

  @override
  String get personaNameLabel => '名字';

  @override
  String get personaAboutLabel => '简介';

  @override
  String get personaAboutHint => '你在故事里是谁、怎么说话';

  @override
  String get personaSystemLabel => '专用说明';

  @override
  String get personaSystemHint => '可选，额外告诉模型的身份设定';

  @override
  String get personaPostLabel => '补充说明';

  @override
  String get personaPostHint => '可选，对话后追加的提醒';

  @override
  String get savingDots => '保存中…';

  @override
  String get deletingDots => '删除中…';
}
