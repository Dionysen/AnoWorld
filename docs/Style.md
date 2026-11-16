# 界面风格

颜色、圆角、字体从主题与 `AppUiTokens` 读取，不在业务调用处写死。换外观设置后全局控件一起变。

## 当前主题

配色对齐 NativeTavern：内置 `ThemePreset`（浅色 / 灰色 / 石板 / Claude / 薄荷 / 紫色 / Hermes / 海洋 / 深色现代 / 石墨 / 深林 / 咖啡 / 午夜 / 暮色 / Cursor 深色），亮色槽与暗色槽**各自记住**一套 `ThemeTokens` + `packId`；自定义色可改当前槽后「保存为主题」或「恢复默认」。设置 → **外观** 可改：

| 项 | 选项 | 落点 |
| --- | --- | --- |
| 主题模式 | 跟随系统 / 浅色 / 深色 | `AppearanceSettings.mode` → `MaterialApp.themeMode` |
| 主题颜色 | NT 内置预设 + 用户保存包；亮/暗分槽 | `lightTokens`/`darkTokens` + `lightPackId`/`darkPackId`/`customPacks` |
| 自定义颜色 | 逐项 token（背景/文字/强调色三档/气泡等） | 改当前有效槽的 `ThemeTokens`；`AppColorPicker` |
| 字体 | 系统默认，或本机/导入字体文件（对齐 NativeTavern） | `AppearanceSettings.fontFamily` + `fontPath`；`foundation/fonts/` + `AppFontPickerRow` |
| 字体大小 | 滑块 **12–20 px**，步长 **0.5 px**（默认 15） | `AppearanceSettings.fontSize` → body 字号；其它角色按相对 15px 比例缩放 |
| 圆角大小 | 滑块 0–24 px，步长 1（默认 10）；**曲率连续**（超椭圆） | `AppearanceSettings.cornerRadius` → `AppUiTokens.radius` / `AppShapes.continuous` |

`AppTheme.light|dark` 分别取亮/暗槽 tokens，经 `AppColorTokens` 映射到 Material `ColorScheme`（对齐 NativeTavern）：`accent` → `primary`，`secondaryAccent` → `secondary`，`tertiaryAccent` → `tertiary`；选中底用 accent 叠在侧栏色上（`secondaryContainer`）；光标/`textSelection`、开关选中轨、splash/highlight 也跟 accent。大小类控件统一用 `AppSlider`；圆角一律走 `RoundedSuperellipseBorder`。输入框内边距默认 `12×12`（`AppTheme.fieldPadding`）。间距：`AppTheme.spaceXs/Sm/Inline/Md/Lg`。按钮高度 `AppTheme.buttonHeight`（36）。组件在 `lib/foundation/theme/`、`lib/foundation/widgets/`；业务页只用封装控件（`AppButton`、`AppTextField`、`AppSelectField`、`AppSlider`、`AppSegmented`、`AppOptionGroup`、`AppListTile`、`AppFontPickerRow`、`AppColorPicker`、`AppSurface` 等）。

## 布局与窗口

- 桌面最小客户区见 `AppTheme.windowMinSize`（覆盖顶栏与窗口按钮）。
- 页面壳在更小约束下收缩或隐藏标题/操作，禁止黄黑溢出条。
- 桌面窗口位置与大小由基础设施记忆（`WindowGeometryStore`），关闭后再开恢复；最大化状态一并保存。

## 响应式导航（双布局）

断点与壳层在 `lib/foundation/layout/app_layout.dart`、`AppNavShell`（参考 NativeTavern）。

**首页没有底栏/侧栏**；从顶栏进入设置后，设置页才使用分区导航：

| 模式 | 条件 | 设置页导航 |
| --- | --- | --- |
| 竖屏 / 窄屏 | 宽度 `< 600` | **底部导航栏**（通用 / 外观 / AI / 关于） |
| 横屏 / 大屏 | 宽度 `≥ 600` | **左侧导航栏**（同上分区） |

日后若作品区也要多层壳，再在对应页面复用 `AppNavShell`，不要挂到首页根上。

## 沉浸式标题栏

五个平台的内容都进入系统栏区域，不留一条独立的系统标题栏；顶栏填充色与页面背景一致。

- 顶栏高度默认 **36**（`AppTheme.titleBandHeight`），比 Material 默认工具栏矮；macOS 若红绿灯更高，才跟着抬高。
- 手机：状态栏和导航栏透明。页面顶栏包含状态栏高度，内容从顶栏下面开始。
- macOS：窗口内容铺到红绿灯下面。顶栏让出红绿灯的宽度，系统按钮保留。
- Windows 和 Linux：系统标题栏隐藏。最小化、最大化、关闭画在顶栏右侧。空白的顶栏可以拖动窗口，双击切换最大化。

通道没有实现时（测试、还没接上的窗口）仍显示页面顶栏，不画窗口按钮。
