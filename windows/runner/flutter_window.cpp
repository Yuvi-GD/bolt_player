#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

// Custom message for SMTC button presses (must match smtc_handler.cpp)
#define WM_SMTC_BUTTON_PRESSED (WM_USER + 100)

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  // Initialize SMTC with the engine and window handle
  smtc_handler_.Initialize(flutter_controller_->engine(), GetHandle());

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  smtc_handler_.Dispose();

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_SMTC_BUTTON_PRESSED: {
      // Handle SMTC button press on the main thread
      // wparam contains the button ID as int
      int button_id = static_cast<int>(wparam);
      std::string button_name;
      // Map button IDs (matches SystemMediaTransportControlsButton enum)
      switch (button_id) {
        case 0: button_name = "play"; break;
        case 1: button_name = "pause"; break;
        case 2: button_name = "stop"; break;
        // case 3: button_name = "record"; break;
        case 4: button_name = "fastForward"; break;
        case 5: button_name = "rewind"; break;
        case 6: button_name = "next"; break;
        case 7: button_name = "previous"; break;
        // case 8: button_name = "channelUp"; break;
        // case 9: button_name = "channelDown"; break;
        default: break;
      }
      if (!button_name.empty()) {
        smtc_handler_.SendButtonToFlutter(button_name);
      }
      return 0;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
