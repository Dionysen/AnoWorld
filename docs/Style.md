# 界面风格

颜色、圆角、字体从主题与 `AppUiTokens` 读取，不在业务调用处写死。换外观设置后全局控件一起变。

## 当前主题

配色对齐 NativeTavern：内置 `ThemePreset`（浅色 / 灰色 / 石板 / Claude / 薄荷 / 紫色 / Hermes / 海洋 / 深色现代 / 石墨 / 深林 / 咖啡 / 午夜 / 暮色 / Cursor 深色），亮色槽与暗色槽**各自记住**一套 `ThemeTokens` + `packId`；自定义色可改当前槽后「保存为主题」或「恢复默认」。内置亮色预设（浅色 / 灰色 / 石板 / Claude Code / 薄荷 / 紫色 / Hermes）共用一套飞书式对比度：主字 `#1F2329`、次要字 `#646A73`、分割 `#DEE0E3`、强调蓝 `#3370FF`、气泡 `#F5F6F7`；各套仅 `editorSurface` / `sidebarSurface` 色调不同（见 `ThemeTokens.lightPreset`）。暗色预设默认主字 `#EBEBEB`、次要字 `#B0B0B0`（配色主题如石墨 / 深林等仍用略暖略冷的提亮主字，见 `ThemeTokens.darkPreset`）。设置 → **外观** 可改：

| 项 | 选项 | 落点 |
| --- | --- | --- |
| 主题模式 | 列表行点开抽屉选：跟随系统 / 浅色 / 深色；行尾显示当前 | `AppearanceSettings.mode` → `MaterialApp.themeMode`；`showAppSheet` |
| 主题颜色 | 浮层抽屉（`AppSheetSize.half`）选 NT 内置 + 用户包；亮/暗分槽；行尾显示当前包名 | `showAppSheet`；`lightTokens`/`darkTokens` + `lightPackId`/`darkPackId`/`customPacks` |
| 自定义颜色 | 浮层抽屉（`half`）；逐项 token | `showAppSheet`；`ThemeTokens`；`AppColorPicker`；行尾 `AppForwardIcon` |
| 字体 | 浮层抽屉（`half`）；系统默认 / 本机 / 导入 | `AppearanceSettings.fontFamily` + `fontPath`；`AppFontPickerRow` + `showAppSheet` |
| 字体大小 | 滑块 **12–20 px**，步长 **0.5 px**（默认 15） | `AppearanceSettings.fontSize` → body 字号；其它角色按相对 15px 比例缩放 |
| 圆角大小 | 滑块 0–24 px，步长 1（默认 10）；**曲率连续**（超椭圆） | `AppearanceSettings.cornerRadius` → `AppUiTokens.radius` / `AppShapes.continuous`；例外：[`AppSearchField`](../lib/foundation/widgets/app_search_field.dart)、底栏胶囊、[`AppCircleButton`](../lib/foundation/widgets/app_circle_button.dart) 固定几何，不跟此滑块 |

`AppTheme.light|dark` 分别取亮/暗槽 tokens，经 `AppColorTokens` 映射到 Material `ColorScheme`（对齐 NativeTavern）：`accent` → `primary`，`secondaryAccent` → `secondary`，`tertiaryAccent` → `tertiary`；选中底用 accent 叠在侧栏色上（`secondaryContainer`）；光标/`textSelection`、开关选中轨、splash/highlight 也跟 accent。大小类控件统一用 `AppSlider`（与 `AppListTile` 同为整行扁平样式：无岛状底、行下发丝线；行内上下 `spaceInline`，标题与滑轨间距 `spaceSm`；滑轨相对标题行再左右对称内缩：有 icon 时两侧均为 icon+`spaceInline`，与标题文案左缘对齐；轨道无刻度点，`step` 仅在松手/拖动时吸附）；`AppSurface(elevated: true)` 与图节点 [`GraphNodeCard`](../lib/foundation/graph/graph_node_card.dart) 用 `AppTheme.surfaceElevation` 投下阴影；画布与「小屏卡片」聚焦视角共用同一套 UE 式节点（[`GraphViewport.focusSelected`](../lib/foundation/graph/graph_viewport.dart)）：色条标题栏显示站名（可选一行副标题），右侧小芯片显示种类；种类色为内置固定色（[`StoryNodeKindStyle`](../lib/create/main_graph/story_node_kind_style.dart)：开场青绿 / 过程钢蓝 / 转折琥珀 / 结束紫），不跟主题包走；内容区按行排布插头，左侧「进入」、右侧每条出线为可点标题按钮（继续 / 岔路 / 添加），与 [`GraphPort`](../lib/foundation/graph/graph_port.dart) 水平对齐；标题最多 15 字，超出加省略号，节点宽度随最长插头标题自适应（[`GraphPortTitle`](../lib/foundation/graph/graph_port_title.dart)）；点标题打开编辑抽屉可改说明并用 AI 展开；高度由 [`GraphEdgeGeometry.heightForOutputCount`](../lib/foundation/graph/graph_edge_geometry.dart) 按行数计算；连线为右出左入三次贝塞尔、**无线上文字与箭头**，可点选高亮线与两端插头；圆角一律走 `RoundedSuperellipseBorder`。情节站编辑抽屉用 `AppSheetSize.compact` 按内容高度收起。输入框内边距默认 `12×12`（`AppTheme.fieldPadding`）。设置类字符串用 [`AppTextEditTile`](../lib/foundation/widgets/app_text_edit_tile.dart)（左 icon+标题/副标题，右当前值，点开抽屉编辑）；表单内联仍用 [`AppTextField`](../lib/foundation/widgets/app_text_field.dart)（`label` 为空则不画标签）。间距：`spaceXs` **4** / `spaceSm` **8** / `spaceGroup` **6** / `spaceInline` **12** / `spaceMd` **16** / `spaceLg` **24**；`pagePadding` = `spaceMd`。列表行偏 X：透明底、无圆角岛状块；设置页 / 列表页 / **抽屉内列表行**内容区横向贴边（选中底与发丝线顶到抽屉卡片左右缘），行用 `spaceMd` 作内容左右边距；相邻行**不加**纵向空隙，行底用 [`AppListHairline`](../lib/foundation/widgets/app_list_hairline.dart)（`dividerColor` 轻叠 `onSurface`，深色约 4% / 浅色约 2.8%）；行内上下留白 `spaceInline`（12）。非列表控件（分区头、分段开关、输入框、按钮等）用 [`AppPageGutter`](../lib/foundation/widgets/app_page_gutter.dart) 或 `AppSectionHeader(gutter: true)` / 抽屉内 `pagePadding` 与行文案对齐；禁止再给 `AppListTile` 外包一层左右 `pagePadding`。分区间仍用 `spaceLg`。`AppSectionHeader` 有副标题时下边距 `spaceMd`、无则 `spaceSm`。`AppButton` 三档（primary / secondary / ghost）共用高度 `AppTheme.buttonHeight`（**36**）与同一套内边距；对话框取消用 secondary、确定用 primary，二者同高同垫。列表顶搜索 [`AppSearchField`](../lib/foundation/widgets/app_search_field.dart) 高度 `buttonHeight`（**36**），边框半径固定为高度一半（胶囊），**不读**圆角滑块。单行命名类确认用居中 [`showAppPromptDialog`](../lib/foundation/widgets/app_prompt_dialog.dart)（`AlertDialog` + `AppTextField` / `AppButton`，形状走 `AppUiTokens`）。圆形图标钮 [`AppCircleButton`](../lib/foundation/widgets/app_circle_button.dart) 固定 `CircleBorder`（默认直径 **40**），**不读**圆角滑块；`tonal` 有常态底（页面返回、情节图画布右下角「整理排版 / 加一站」、选中站上方「复制 / 编辑 / 删除」）；`ghost` 无常态底、仅悬停/按下显墨水；页面返回用 `tonal`（桌面大标题左侧默认 40，窄顶栏内 32）。标题行工具图标 [`AppIconButton`](../lib/foundation/widgets/app_icon_button.dart) 默认命中区 **40**、字形 **22**（与圆钮同档）。[`AppPage.actions`](../lib/foundation/widgets/app_page.dart) 经 `spacedActions` 自动插入钮间距 `spaceSm`。情节图 actions 为与返回同款的 `AppCircleButton`「撤销 / 重做 / 更多」（桌面与大标题「情节走向」同一行右对齐；窄屏仍在标题带内与标题同行；由右向左为更多→重做→撤销；不可用时 `onPressed: null`）；「更多」抽屉内「显示网格」用 `AppSwitch`；网格为视口层 [`GraphGridPainter`](../lib/foundation/graph/graph_grid_painter.dart)（`outline` 底色，次线/主线透明度约 0.38 / 0.62，间距由 [`GraphGridLod`](../lib/foundation/graph/graph_grid_lod.dart) 按缩放取 1–2–5 序列，目标约 32px）；节点连线默认 `onSurface` 约 55% 透明（选中仍用 `primary`）。选中站时操作钮在视口层跟随节点（`Transform` 映射；画布子树顶部留 `sceneTopInset`，y=0 的站仍能点到钮；不夹死在半屏），加站/整理叠在画布视口右下角（不随镜头平移）。组件在 `lib/foundation/theme/`、`lib/foundation/widgets/`；业务页只用封装控件（`AppButton`、`AppCircleButton`、`AppIconButton`、`AppPressScale`、`AppTextField`（可选 `minLines`/`maxLines` 多行）、`AppTextEditTile`、`AppSelectField`、`AppSlider`、`AppSegmented`、`AppOptionGroup`、`AppListTile`、`AppDetailSection`、`AppDisclosureIcon`、`AppForwardIcon`、`AppFontPickerRow`、`AppColorPicker`、`AppSurface`、`showAppSheet`、聊天 [`AppChatBubble`](../lib/foundation/widgets/app_chat_bubble.dart) / [`AppChatComposer`](../lib/foundation/widgets/app_chat_composer.dart) / [`AppChatDialogueText`](../lib/foundation/widgets/app_chat_dialogue_text.dart) 等）。

- 导入角色卡等只读预览可用 [`AppMarkdown`](../lib/foundation/widgets/app_markdown.dart)（`flutter_markdown` 封装，主题字号来自 `AppTheme`）；游玩聊天/VN 气泡暂不渲染 Markdown。

### 聊天（对齐 NativeTavern Zephyr）

- 色：`ThemeTokens` 的 `chatBackground` / `characterBubble` / `userBubble` / `chatText` / `dialogueText` → [`AppChatColors`](../lib/foundation/theme/app_chat_colors.dart) ThemeExtension。
- 形：[`AppChatChrome`](../lib/foundation/theme/app_chat_chrome.dart) — 气泡 `ContinuousRectangleBorder`（外侧上角直角、默认圆角 **30**，可调 **0–50**）、composer 近胶囊半径 **50**；用户气泡为 accent 叠 surface，角色气泡用 `characterBubble`。
- 引号对白（`"…"` / `“…”` / `「…」`）用 `dialogueText` + bold。
- 聊天背景：[`AppChatBackground`](../lib/foundation/theme/app_chat_background.dart) + [`AppChatBackgroundLayer`](../lib/foundation/widgets/app_chat_background.dart)（主题 `chatBackground` 为底，可叠纯色 / 内置渐变预设；默认「主题默认」）。
- 游玩聊天壳：[PlayChatView](../lib/play/play_chat_view.dart)（列表顶对齐；底部按 composer 实测高度留白，避免挡气泡/回复选项；新消息自动滚到底；「回复选项」在列表末尾随气泡滚动；浮动 composer；空态大头像 +「开始对话」；助手生成中显示 typing 气泡）。Composer 左侧对齐 NT：`选择模型`（`smart_toy_outlined` → [`pickAndApplyTextModel`](../lib/settings/ai_model_picker.dart)，半屏两步：模型 → 思考程度）与 `聊天设置`（进 [`ChatSettingsPage`](../lib/play/chat_settings_page.dart)，非全局设置）；无「重新开始」。[`ChatUiSettings`](../lib/domain/settings/chat_ui_settings.dart) 控制行距（默认 **1.4**）、段间距（默认 **8**）、气泡圆角、角色/我的头像显隐、头像在气泡上方或并排、是否显示思考过程、聊天背景；正文经 [`AppChatDialogueText`](../lib/foundation/widgets/app_chat_dialogue_text.dart) 按空行分段；思考过程用 [`AppChatReasoning`](../lib/foundation/widgets/app_chat_reasoning.dart) 折叠块。助手回复从接口取 `reasoning_content` / `reasoning` / `thought`，或正文前导 `<think>` 等标签（[`ThinkTagParser`](../lib/foundation/ai/think_tag_parser.dart)），写入存档 `chat[].reasoning`；开关只控制显隐，不重新拉取。顶栏右侧在末条为助手且未生成中时显示 `重新生成回复`（`AppCircleButton` + `refresh_rounded`，对齐 NT AppBar regenerate）。聊天页顶栏标题经 `AppPage.titleWidget` 用 `AppTextRole.subtitle`（`titleMedium` **16**），小于其它页的 `pageTitle`（**24**）；视觉小说游玩标题仍用默认 `pageTitle`。
- 回复选项芯片：[`AppChatChrome.tappableMenuChip`](../lib/foundation/theme/app_chat_chrome.dart)（主题圆角 + 浅底描边，对齐 NT Zephyr menuChip）。
- 气泡角色（酒馆回合）：助手左对齐、玩家右对齐；一轮助手正文可含多角色/旁白，仍算左侧一条。OpenAI 兼容 HTTP / Base URL 规范化 / JSON 候选解码在 `lib/foundation/ai/`，无业务类型。**所有抽屉**统一走 `showAppSheet`（左右/底边距 `sheetInset`、最大宽 `sheetMaxWidth`、抬高层色 `surfaceContainerHigh`、四角连续圆角；遮罩点击在打开后两帧才生效；`GlobalKey` 固定在 Stateful frame；底边加上 `viewInsets` 随键盘上移，对齐 NativeTavern）。打开高度用 `AppSheetSize`：`compact` 按内容高度、`half` 默认半屏（`sheetHalfHeightFactor`）且可上拖到近满屏（`sheetFullHeightFactor`，吸附半/满两档）、`full` 近满屏。半屏下过小或快甩向下可关闭；表单类编辑用 [`AppSheetEditForm`](../lib/foundation/widgets/app_sheet.dart)（右上 **保存**、`PopScope` 脏数据拦截 + [`showAppSheetDiscardEditsConfirm`](../lib/foundation/widgets/app_sheet.dart)）+ [`AppSheetScrollBody`](../lib/foundation/widgets/app_sheet.dart) 滚动字段；销毁类操作放在表单内次要按钮；`enableDrag: false` 时高度固定。需要把纵向手势留给内容时设 `enableDrag: false`，仅顶部 `AppSheetDragHandle` 与包了 `AppSheetDragToDismiss` 的标题可下拖关闭。底栏上方停靠面板用 `AppDockedPanel`（同款表面/圆角/限宽），经 `AppNavShell.bottomPanel` 叠在胶囊之上的空隙里；开关为约 180ms 自底部滑入/滑出（`Curves.easeOut`，无过弹），程序关闭走 `AppDockedPanelState.dismiss`；有面板时 `AppNavShell` 铺透明遮罩挡住 body 点击，`onBottomPanelBarrierTap` 用于点外侧关闭；底栏胶囊仍可点；手柄与可选 `header` 跟手下拖，松手不足阈值回弹，超过阈值或甩出则滑走关闭；右侧扩展胶囊可用 `AppBottomNavExtraCapsule.selected` 表示开合。列表类抽屉（主题颜色 / 自定义颜色 / 字体 / 选供应商 / 选模型）默认 `half`；标题与副标题放在 `Expanded` 列表外，滚动时保持可见。带说明的分区头用 `AppSectionHeader(subtitle: …)`：标题与副标题间距 `spaceXs`，整块下边距见上。禁止业务侧直接 `showModalBottomSheet`。可折叠行尾用上下箭头（`AppDisclosureIcon`）；打开抽屉的行尾可用右箭头（`AppForwardIcon`），不用「展开/收起」文案。列表行 / 滑块 / 字体行带 leading `icon`。`AppListTile` 尾标按内容宽度占位，标题/副标题吃满中间剩余宽度，副标题最多两行，写不下才省略。[`AppSettingsNestedColumn`](../lib/foundation/widgets/app_nested_settings_group.dart) 默认无额外空隙（行自带发丝线）。二级行 / 滑块设 `nested: true` 仅多一段左侧缩进；说明性 [`AppSurface`](../lib/foundation/widgets/app_surface.dart)(`nested: true`) 仍可用浅底 + `outline` 描边。`AppSegmented` 选项可带 `icon`（在文字左侧），行高与纯文字时一致。

## 布局与窗口

- 桌面最小客户区见 `AppTheme.windowMinSize`（覆盖顶栏与窗口按钮）。
- 页面壳在更小约束下收缩或隐藏标题/操作，禁止黄黑溢出条。
- 桌面窗口位置与大小由基础设施记忆（`WindowGeometryStore`），关闭后再开恢复；最大化状态一并保存。

## 响应式导航（双布局）

断点与壳层在 `lib/foundation/layout/app_layout.dart`、`AppNavShell`、`AppPage`（参考 NativeTavern）。**同宽度 ⇒ 同壳层**（桌面竖屏 / 窄窗与手机一致）；导航按宽度切换，不按 `TargetPlatform`。桌面自定义标题栏只铺背景；软件标题栏在其下（见「沉浸式标题栏」）。

首页、设置与情节图复用 `AppNavShell`：

| 页面 | 条件 | 导航 / 标题 |
| --- | --- | --- |
| 首页 | 宽度 `< 600` | **主胶囊**会话 / 故事 / 玩法 / 我；**无**软件标题栏（搜索/工具在正文顶） |
| 首页 | 宽度 `≥ 600` | **左侧导航栏**；同样无软件标题栏 |
| 设置 | 宽度 `< 600` | **悬浮胶囊底栏**；chrome 下有软件标题栏（返回+「设置」） |
| 设置 | 宽度 `≥ 600` | **左侧导航栏**；同样 chrome 下软件标题栏 |
| 情节走向 | 任意宽度（`forceCompact: true`） | **主胶囊**画布 / 卡片 + **右侧独立胶囊**全图（`AppBottomNavExtraCapsule`，仅画布可用） |

故事库进入/退出文件夹时，列表用约 280ms 的水平滑动 + 淡入淡出（`AnimatedSwitcher` + `SlideTransition`）。首页四分区不画 `AppPage` 标题；会话/故事为「搜索 → 工具行 → 列表」，工具行与搜索同用 `pagePadding`；「我」为右上齿轮 + [`MeUserHeader`](../lib/home/me_user_header.dart)（与设置 [`AppListTile`](../lib/foundation/widgets/app_list_tile.dart) 同行高：[`AppPersonAvatar`](../lib/foundation/widgets/app_person_avatar.dart) **40** + 名字/简介 + `AppForwardIcon`）。故事库四种布局（详细列表 / 简洁列表 / 网格 / 紧凑网格）与列表头像形状（圆 / 方 / 竖矩）见 [`LibraryDisplayController`](../lib/home/library_display_prefs.dart)；网格卡用 [`AppCoverTile`](../lib/foundation/widgets/app_cover_tile.dart)，头像用 [`AppShapedAvatar`](../lib/foundation/widgets/app_shaped_avatar.dart)。故事列表末尾加号控件与故事同形（网格为无底栏封面卡，列表为同形头像钮，皆无文案）；带 `AppPressScale` 与 Ink hover/按下反馈；点开菜单项统一 `AppListTile`。

窄屏底栏尺寸见 `AppLayout.bottomNavHeight` / `bottomNavHorizontalInset` / `bottomNavBottomInset` / `bottomNavBlurSigma`；胶囊圆角固定为高度一半，不跟控件圆角滑块走。胶囊以 `Stack` 叠在内容之上，四周留白透明；本体为半透明表面 + `BackdropFilter` 毛玻璃模糊（对齐新版 iOS 胶囊质感）。底栏项与侧栏项按下用统一 [`AppPressScale`](../lib/foundation/widgets/app_press_scale.dart)（缩至 `AppTheme.pressScale` **0.92**，`pressScaleDuration` **120ms**，`easeOutCubic`）。`AppPage` 不预扣底边，`AppPageBody` 与情节图画布读 `MediaQuery.padding.bottom`（壳层会加上胶囊高度）以免内容被挡。以通栏列表为主的页面用 [`AppPageBody.list`](../lib/foundation/widgets/app_page.dart)（仅上下 `pagePadding`）；多块列表无行间距时用 [`AppListTileStack`](../lib/foundation/widgets/app_list_tile.dart)。

## 沉浸式标题栏

五个平台的内容都进入系统栏区域，不留一条独立的系统标题栏；顶栏填充色与页面背景一致。

- **双层顶栏**（[`AppPage`](../lib/foundation/widgets/app_page.dart)）：
  1. **窗口 / 状态 chrome**：与页面同色背景。桌面为自定义标题栏（高度 `AppTheme.titleBandHeight` **44**，macOS 可抬高对齐红绿灯）；**禁止**在此层放返回、标题、`actions` 或任何业务文字/控件。移动端仅 `statusInset`（`titleBarHeight: 0`）。
  2. **软件标题栏**（`AppTheme.pageTitleBarHeight` **44**）：在 chrome **下方**；非主页放返回（**32**）+ 标题（`AppTextRole.subtitle`）+ `actions`。主页 `showTitle: false` 时不画这一层。
- 桌面窗口能力：macOS 红绿灯区可拖动；Windows / Linux 自绘最小化/最大化/关闭（宽度够时才画）；双击切换最大化。不驱动第二套业务布局。
- 圆形图标按钮：形状**一律正圆**，不读外观圆角滑块。[`AppCircleButton`](../lib/foundation/widgets/app_circle_button.dart) 默认 **40**；[`AppIconButton`](../lib/foundation/widgets/app_icon_button.dart) 为同款 `ghost` 封装（故事工具行 + / 导入 / 更多等）。软件标题栏返回 **32**；`ghost` 未按下无底色，按下/悬停仍有 ink；主色 CTA 用 `filled`（`AppCircleButton.fab` 默认 **54** / 图标 **30**）。画布角上次要圆钮显式 `ghost` FAB。窄屏底栏时 FAB 用 [`AppFabLocation.aboveCompactBottomNav`](../lib/foundation/widgets/app_fab_location.dart) 抬高。
- 故事详情 [`AppDetailSection`](../lib/foundation/widgets/app_detail_section.dart)：扁平分区（无外卡）；标题行 icon+标题+编辑；条目上下 `spaceInline`、底用 [`AppListHairline`](../lib/foundation/widgets/app_list_hairline.dart)；条内文案 `compactLabel` / `compactBody`，标签 `compactTag`（主色浅底 chip）。封面 16:9 横向贴边、直角无圆角；右上角圆形钮可更换图片（存 `assets/cover.*`，`ProjectMeta.coverPath`）。窄屏底栏胶囊高度/边距见 `AppLayout.bottomNav*`。

通道没有实现时（测试、还没接上的窗口）仍显示页面顶栏，不画窗口按钮。
