import 'package:anoworld/app/l10n/app_strings.dart';
import 'package:anoworld/foundation/theme/app_shapes.dart';
import 'package:anoworld/foundation/theme/app_theme.dart';
import 'package:anoworld/foundation/theme/app_ui_tokens.dart';
import 'package:anoworld/foundation/widgets/app_page_gutter.dart';
import 'package:anoworld/foundation/widgets/app_section_header.dart';
import 'package:anoworld/foundation/widgets/app_text.dart';
import 'package:flutter/widgets.dart';

/// Brand facts that do not change with language.
abstract final class AppAbout {
  static const name = 'AnoWorld';
  static const version = '1.0.0';
  static const iconAsset = 'assets/branding/app_icon.png';
}

class AboutPanel extends StatelessWidget {
  const AboutPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final radius = AppUiTokens.of(context).radius;
    return AppPageGutter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(strings.settingsSectionAbout),
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
          AppText(
            strings.appTagline,
            role: AppTextRole.subtitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          AppText(strings.appDescription, role: AppTextRole.body),
          const SizedBox(height: AppTheme.spaceMd),
          AppText(
            strings.appVersion(AppAbout.version),
            role: AppTextRole.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
