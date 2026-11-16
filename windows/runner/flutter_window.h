#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/method_result.h>

#include <memory>

#include "win32_window.h"

// Hosts a Flutter view with an immersive caption: the client area includes the
// title band, and min / max / close stay window buttons drawn by Flutter.
class FlutterWindow : public Win32Window {
 public:
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  friend LRESULT CALLBACK CaptionChildProc(HWND hwnd, UINT message,
                                            WPARAM wparam, LPARAM lparam);

  void EnsureChildHook();
  void HandleWindowMethod(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  LRESULT CaptionHitTest(LPARAM lparam);
  void ApplyMaximizedClientArea(HWND window, LPARAM lparam) const;
  void NotifyZoomed() noexcept;
  void StartDragging();
  int FrameBorder();
  void SetMinimumClientSize(int width, int height);

  flutter::DartProject project_;
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;

  HWND child_hwnd_ = nullptr;
  WNDPROC original_child_proc_ = nullptr;
  bool zoomed_ = false;
  bool zoomed_reported_ = false;
  // Client-area floor so chrome is not crushed by resize.
  int min_client_width_ = 298;
  int min_client_height_ = 116;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
