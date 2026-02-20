#ifndef RUNNER_SMTC_HANDLER_H_
#define RUNNER_SMTC_HANDLER_H_

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/flutter_engine.h>

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Media.h>
#include <winrt/Windows.Storage.Streams.h>

#include <memory>
#include <string>

class SmtcHandler {
 public:
  SmtcHandler();
  ~SmtcHandler();

  // Initialize the SMTC with the Flutter engine and HWND
  void Initialize(flutter::FlutterEngine* engine, HWND hwnd);

  // Cleanup
  void Dispose();

  // Send a button press event to Flutter (called from the main thread)
  void SendButtonToFlutter(const std::string& button_name);

 private:
  // Method channel handler
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Helper methods
  void UpdateMetadata(const std::string& title, const std::string& artist,
                      const std::string& album, const std::string& thumbnail_url);
  void UpdatePlaybackStatus(bool is_playing);
  void SetEnabled(bool enabled);
  void SetThumbnailFromUrl(const std::string& url);

  // Members
  winrt::Windows::Media::SystemMediaTransportControls smtc_{nullptr};
  winrt::event_token button_pressed_token_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  flutter::FlutterEngine* engine_ = nullptr;
  HWND hwnd_ = nullptr;
  bool initialized_ = false;
  std::string last_thumbnail_url_;
};

#endif  // RUNNER_SMTC_HANDLER_H_
