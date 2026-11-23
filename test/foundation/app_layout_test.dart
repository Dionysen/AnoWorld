import 'package:anoworld/foundation/layout/app_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compact below rail breakpoint', () {
    expect(AppLayout.useRail(599), isFalse);
    expect(chromeModeForWidth(400), AppChromeMode.compact);
  });

  test('expanded at and above rail breakpoint', () {
    expect(AppLayout.useRail(600), isTrue);
    expect(chromeModeForWidth(1280), AppChromeMode.expanded);
  });

  test('three pane needs secondary and enough width', () {
    expect(
      AppLayout.useThreePane(shellWidth: 900, hasSecondary: false),
      isFalse,
    );
    // Content after rail at 600px is below secondary+detail minimum.
    expect(
      AppLayout.useThreePane(shellWidth: 600, hasSecondary: true),
      isFalse,
    );
    expect(
      AppLayout.useThreePane(shellWidth: 1000, hasSecondary: true),
      isTrue,
    );
  });

  group('master-detail split', () {
    test('needs master + handle + detail to fit', () {
      expect(
        AppLayout.masterDetailContentMinWidth,
        AppLayout.masterPaneMinWidth +
            AppLayout.paneResizeHandleWidth +
            AppLayout.detailPaneMinWidth,
      );
      expect(
        AppLayout.useMasterDetail(
          AppLayout.masterDetailContentMinWidth - 1,
        ),
        isFalse,
      );
      expect(
        AppLayout.useMasterDetail(AppLayout.masterDetailContentMinWidth),
        isTrue,
      );
    });

    test('clamp keeps both panes above their minimums', () {
      const contentWidth = 1000.0;
      final maxPane =
          contentWidth - AppLayout.detailPaneMinWidth -
          AppLayout.paneResizeHandleWidth;

      expect(
        AppLayout.clampMasterPaneWidth(
          desired: 120,
          contentWidth: contentWidth,
        ),
        AppLayout.masterPaneMinWidth,
      );
      expect(
        AppLayout.clampMasterPaneWidth(
          desired: 4000,
          contentWidth: contentWidth,
        ),
        maxPane,
      );
      expect(
        AppLayout.clampMasterPaneWidth(
          desired: 420,
          contentWidth: contentWidth,
        ),
        420,
      );
    });

    test('too-narrow host falls back to the master minimum', () {
      expect(
        AppLayout.clampMasterPaneWidth(
          desired: 500,
          contentWidth: AppLayout.masterDetailContentMinWidth - 1,
        ),
        AppLayout.masterPaneMinWidth,
      );
    });
  });
}
