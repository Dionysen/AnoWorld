import 'package:anoworld/foundation/theme/app_shapes.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/theme/app_ui_tokens.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:flutter/widgets.dart';

/// Product blurb shown under 关于.
abstract final class AppAbout {
  static const name = 'AnoWorld';
  static const versionLabel = '版本 1.0.0';
  static const tagline = '视觉小说创作器 + 运行时';
  static const description =
      '本地配置文本与生图 AI，结构化创作剧本，用聊天式或视觉小说式双模式验本与游玩。'
      'SillyTavern 角色卡仅作素材入口，不是兼容目标。';
  static const iconAsset = 'assets/branding/app_icon.png';
}

class AboutPanel extends StatelessWidget {
  const AboutPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final radius = AppUiTokens.of(context).radius;
    return AppPageGutter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSectionHeader('关于'),
          const SizedBox(height: AppTheme.spaceSm),
          Center(
            child: ClipPath(
              clipper: AppShapes.clipper(radius: radius),
              child: const Image(
                image: AssetImage(AppAbout.iconAsset),
                width: 88,
                height: 88,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          const AppText(
            AppAbout.name,
            role: AppTextRole.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spaceXs),
          const AppText(
            AppAbout.tagline,
            role: AppTextRole.subtitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          const AppText(AppAbout.description, role: AppTextRole.body),
          const SizedBox(height: AppTheme.spaceMd),
          const AppText(
            AppAbout.versionLabel,
            role: AppTextRole.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
