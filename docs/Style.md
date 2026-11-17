# 界面风格

颜色、圆角、字体从主题与 `AppUiTokens` 读取，不在业务调用处写死。换外观设置后全局控件一起变。

## 当前主题

配色对齐 NativeTavern：内置 `ThemePreset`（浅色 / 灰色 / 石板 / Claude / 薄荷 / 紫色 / Hermes / 海洋 / 深色现代 / 石墨 / 深林 / 咖啡 / 午夜 / 暮色 / Cursor 深色），亮色槽与暗色槽**各自记住**一套 `ThemeTokens` + `packId`；自定义色可改当前槽后「保存为主题」或「恢复默认」。设置 → **外观** 可改：

| 项 | 选项 | 落点 |
| --- | --- | --- |
| 主题模式 | 跟随系统 / 浅色 / 深色 | `AppearanceSettings.mode` → `MaterialApp.themeMode` |
| 主题预设 | 浮层抽屉（`AppSheetSize.half`）选 NT 内置 + 用户包；亮/暗分槽；行尾显示当前包名 | `showAppSheet`；`lightTokens`/`darkTokens` + `lightPackId`/`darkPackId`/`customPacks` |
| 自定义颜色 | 浮层抽屉（`half`）；逐项 token | `showAppSheet`；`ThemeTokens`；`AppColorPicker`；行尾 `AppForwardIcon` |
| 字体 | 浮层抽屉（`half`）；系统默认 / 本机 / 导入 | `AppearanceSettings.fontFamily` + `fontPath`；`AppFontPickerRow` + `showAppSheet` |
| 字体大小 | 滑块 **12–20 px**，步长 **0.5 px**（默认 15） | `AppearanceSettings.fontSize` → body 字号；其它角色按相对 15px 比例缩放 |
| 圆角大小 | 滑块 0–24 px，步长 1（默认 10）；**曲率连续**（超椭圆） | `AppearanceSettings.cornerRadius` → `AppUiTokens.radius` / `AppShapes.continuous` |

`AppTheme.light|dark` 分别取亮/暗槽 tokens，经 `AppColorTokens` 映射到 Material `ColorScheme`（对齐 NativeTavern）：`accent` → `primary`，`secondaryAccent` → `secondary`，`tertiaryAccent` → `tertiary`；选中底用 accent 叠在侧栏色上（`secondaryContainer`）；光标/`textSelection`、开关选中轨、splash/highlight 也跟 accent。大小类控件统一用 `AppSlider`（标题、数值与滑轨同处一块 `surfaceContainerHighest` 表面内，与 `AppListTile` 视觉对齐；块内上下边距 `spaceMd`，标题与滑轨间距 `spaceSm`）；`AppSurface(elevated: true)` 与图节点 [`GraphNodeCard`](../lib/foundation/graph/graph_node_card.dart) 用 `AppTheme.surfaceElevation` 投下阴影；画布与「小屏卡片」聚焦视角共用同一套 UE 式节点（[`GraphViewport.focusSelected`](../lib/foundation/graph/graph_viewport.dart)）：色条标题栏显示站名（可选一行副标题），右侧小芯片显示种类；种类色为内置固定色（[`StoryNodeKindStyle`](../lib/create/main_graph/story_node_kind_style.dart)：开场青绿 / 过程钢蓝 / 转折琥珀 / 结束紫），不跟主题包走；内容区按行排布插头，左侧「进入」、右侧每条出线为可点标题按钮（继续 / 岔路 / 添加），与 [`GraphPort`](../lib/foundation/graph/graph_port.dart) 水平对齐；标题最多 15 字，超出加省略号，节点宽度随最长插头标题自适应（[`GraphPortTitle`](../lib/foundation/graph/graph_port_title.dart)）；点标题打开编辑抽屉可改说明并用 AI 展开；高度由 [`GraphEdgeGeometry.heightForOutputCount`](../lib/foundation/graph/graph_edge_geometry.dart) 按行数计算；连线为右出左入三次贝塞尔、**无线上文字与箭头**，可点选高亮线与两端插头；圆角一律走 `RoundedSuperellipseBorder`。情节站编辑抽屉用 `AppSheetSize.compact` 按内容高度收起。输入框内边距默认 `12×12`（`AppTheme.fieldPadding`）。间距：`AppTheme.spaceXs/Sm/Group/Inline/Md/Lg`；同一分区内相邻控件用 `spaceGroup`（6），分区间仍用 `spaceLg`。`AppButton` 三档（primary / secondary / ghost）共用高度 `AppTheme.buttonHeight`（36）与同一套内边距；对话框取消用 secondary、确定用 primary，二者同高同垫。圆形图标钮 [`AppCircleButton`](../lib/foundation/widgets/app_circle_button.dart) 固定 `CircleBorder`（默认直径 **40**），**不读**圆角滑块；`tonal` 有常态底（页面返回、情节图画布右下角「整理排版 / 加一站」、选中站上方「复制 / 编辑 / 删除」）；`ghost` 无常态底、仅悬停/按下显墨水；页面返回用 `tonal`（桌面大标题左侧默认 40，窄顶栏内 32）。标题行工具图标 [`AppIconButton`](../lib/foundation/widgets/app_icon_button.dart) 默认命中区 **40**、字形 **22**（与圆钮同档）。[`AppPage.actions`](../lib/foundation/widgets/app_page.dart) 经 `spacedActions` 自动插入钮间距 `spaceSm`。情节图 actions 为与返回同款的 `AppCircleButton`「撤销 / 重做 / 更多」（桌面与大标题「情节走向」同一行右对齐；窄屏仍在标题带内与标题同行；由右向左为更多→重做→撤销；不可用时 `onPressed: null`）；「更多」抽屉内「显示网格」用 `AppSwitch`；网格为视口层 [`GraphGridPainter`](../lib/foundation/graph/graph_grid_painter.dart)（`outline` 底色，次线/主线透明度约 0.38 / 0.62，间距由 [`GraphGridLod`](../lib/foundation/graph/graph_grid_lod.dart) 按缩放取 1–2–5 序列，目标约 32px）；节点连线默认 `onSurface` 约 55% 透明（选中仍用 `primary`）。选中站时操作钮在视口层跟随节点（`Transform` 映射；画布子树顶部留 `sceneTopInset`，y=0 的站仍能点到钮；不夹死在半屏），加站/整理叠在画布视口右下角（不随镜头平移）。组件在 `lib/foundation/theme/`、`lib/foundation/widgets/`；业务页只用封装控件（`AppButton`、`AppCircleButton`、`AppIconButton`、`AppTextField`（可选 `minLines`/`maxLines` 多行）、`AppSelectField`、`AppSlider`、`AppSegmented`、`AppOptionGroup`、`AppListTile`、`AppDisclosureIcon`、`AppForwardIcon`、`AppFontPickerRow`、`AppColorPicker`、`AppSurface`、`showAppSheet` 等）。OpenAI 兼容 HTTP / Base URL 规范化 / JSON 候选解码在 `lib/foundation/ai/`，无业务类型。**所有抽屉**统一走 `showAppSheet`（左右/底边距 `sheetInset`、最大宽 `sheetMaxWidth`、抬高层色 `surfaceContainerHigh`、四角连续圆角）。打开高度用 `AppSheetSize`：`compact` 按内容高度、`half` 半屏（`sheetHalfHeightFactor`）、`full` 近满屏（`sheetFullHeightFactor`）。默认整页可下拖关闭；需要把纵向手势留给内容时设 `enableDrag: false`，仅顶部 `AppSheetDragHandle` 与包了 `AppSheetDragToDismiss` 的标题可下拖关闭。底栏上方停靠面板用 `AppDockedPanel`（同款表面/圆角/限宽），经 `AppNavShell.bottomPanel` 叠在胶囊之上的空隙里；开关为约 180ms 自底部滑入/滑出（`Curves.easeOut`，无过弹），程序关闭走 `AppDockedPanelState.dismiss`；有面板时 `AppNavShell` 铺透明遮罩挡住 body 点击，`onBottomPanelBarrierTap` 用于点外侧关闭；底栏胶囊仍可点；手柄与可选 `header` 跟手下拖，松手不足阈值回弹，超过阈值或甩出则滑走关闭；右侧扩展胶囊可用 `AppBottomNavExtraCapsule.selected` 表示开合。列表类抽屉（主题预设 / 自定义颜色 / 字体 / 选供应商 / 选模型）默认 `half`；标题与副标题放在 `Expanded` 列表外，滚动时保持可见。带说明的分区头用 `AppSectionHeader(subtitle: …)`：标题与副标题间距 `spaceXs`，整块下边距 `spaceMd`。禁止业务侧直接 `showModalBottomSheet`。可折叠行尾用上下箭头（`AppDisclosureIcon`）；打开抽屉的行尾可用右箭头（`AppForwardIcon`），不用「展开/收起」文案。列表行 / 滑块 / 字体行带 leading `icon`（对齐 NativeTavern settings tile）。`AppListTile` 尾标按内容宽度占位，标题/副标题吃满中间剩余宽度，副标题最多两行，写不下才省略。`AppSegmented` 选项可带 `icon`（在文字左侧；主题模式：跟随系统 / 浅色 / 深色），行高与纯文字时一致。

## 布局与窗口

- 桌面最小客户区见 `AppTheme.windowMinSize`（覆盖顶栏与窗口按钮）。
- 页面壳在更小约束下收缩或隐藏标题/操作，禁止黄黑溢出条。
- 桌面窗口位置与大小由基础设施记忆（`WindowGeometryStore`），关闭后再开恢复；最大化状态一并保存。

## 响应式导航（双布局）

断点与壳层在 `lib/foundation/layout/app_layout.dart`、`AppNavShell`（参考 NativeTavern）。

首页、设置与情节图复用 `AppNavShell`：

| 页面 | 条件 | 导航 |
| --- | --- | --- |
| 首页 | 宽度 `< 600` | **主胶囊**存档 / 作品 + **右侧独立胶囊**设置（`AppBottomNavExtraCapsule`） |
| 首页 | 宽度 `≥ 600` | **左侧导航栏**（存档 / 作品）+ 侧栏底部设置 |
| 设置 | 宽度 `< 600` | **悬浮胶囊底栏**（通用 / 外观 / AI / 关于） |
| 设置 | 宽度 `≥ 600` | **左侧导航栏**（同上分区） |
| 情节走向 | 任意宽度（`forceCompact: true`） | **主胶囊**画布 / 卡片 + **右侧独立胶囊**全图（`AppBottomNavExtraCapsule`，仅画布可用） |

作品库进入/退出文件夹时，列表用约 280ms 的水平滑动 + 淡入淡出（`AnimatedSwitcher` + `SlideTransition`）。首页大标题仅在文案变化时淡入淡出（进出文件夹标题仍为「作品」时不重播，避免闪一下）。作品库四种布局（详细列表 / 简洁列表 / 网格 / 紧凑网格）与列表头像形状（圆 / 方 / 竖矩）见 [`LibraryDisplayController`](../lib/home/library_display_prefs.dart)；网格卡用 [`AppCoverTile`](../lib/foundation/widgets/app_cover_tile.dart)，头像用 [`AppShapedAvatar`](../lib/foundation/widgets/app_shaped_avatar.dart)。

窄屏底栏尺寸见 `AppLayout.bottomNavHeight` / `bottomNavHorizontalInset` / `bottomNavBottomInset` / `bottomNavBlurSigma`；胶囊圆角固定为高度一半，不跟控件圆角滑块走。胶囊以 `Stack` 叠在内容之上，四周留白透明；本体为半透明表面 + `BackdropFilter` 毛玻璃模糊（对齐新版 iOS 胶囊质感）。`AppPage` 不预扣底边，`AppPageBody` 与情节图画布读 `MediaQuery.padding.bottom`（壳层会加上胶囊高度）以免内容被挡。

## 沉浸式标题栏

五个平台的内容都进入系统栏区域，不留一条独立的系统标题栏；顶栏填充色与页面背景一致。

- 顶栏高度默认 **36**（`AppTheme.titleBandHeight`），比 Material 默认工具栏矮；macOS 若红绿灯更高，才跟着抬高。
- 手机 / 平板：状态栏和导航栏透明；页面标题（`AppPage.title`）画在顶栏内，内容从顶栏下面开始。
- 桌面（macOS / Windows / Linux）：顶栏**不画标题文案、返回与页面 `actions`**（只留窗口拖动/系统钮区域）；页面标题落到顶栏下方（上边距 `spaceXs`），用 `AppTextRole.pageTitle`（`headlineSmall` **24** / semibold），左侧圆形返回（`AppCircleButton`），右侧为 `AppPage.actions`（与标题同行）。窗口内容铺到红绿灯或自绘窗口按钮下面；macOS 顶栏让出红绿灯宽度；Windows / Linux 隐藏系统标题栏，最小化/最大化/关闭画在顶栏右侧，空白顶栏可拖动，双击切换最大化。

通道没有实现时（测试、还没接上的窗口）仍显示页面顶栏，不画窗口按钮。
