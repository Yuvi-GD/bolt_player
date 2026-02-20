#include "smtc_handler.h"

#include <flutter/encodable_value.h>
#include <winrt/Windows.Media.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Storage.Streams.h>

#include <iostream>
#include <functional>

#include <systemmediatransportcontrolsinterop.h>
#include <windows.h>
#include <winrt/base.h>

// Custom window message for dispatching SMTC events to the main thread
#define WM_SMTC_BUTTON_PRESSED (WM_USER + 100)

SmtcHandler::SmtcHandler() {}

SmtcHandler::~SmtcHandler() { Dispose(); }

void SmtcHandler::Initialize(flutter::FlutterEngine* engine, HWND hwnd) {
  if (initialized_) return;
  engine_ = engine;
  hwnd_ = hwnd;

  // Create the method channel
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      engine_->messenger(), "bolt_player/smtc",
      &flutter::StandardMethodCodec::GetInstance());

  // Set method call handler (for Dart -> C++ calls)
  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        HandleMethodCall(call, std::move(result));
      });

  // NOTE: Do NOT call winrt::init_apartment() here.
  // Flutter already initializes COM on the main thread.

  // Get SystemMediaTransportControls via ISystemMediaTransportControlsInterop
  try {
    auto interop_factory = winrt::get_activation_factory<
        winrt::Windows::Media::SystemMediaTransportControls,
        ISystemMediaTransportControlsInterop>();

    winrt::Windows::Media::SystemMediaTransportControls smtc{nullptr};
    HRESULT hr = interop_factory->GetForWindow(
        hwnd,
        winrt::guid_of<winrt::Windows::Media::SystemMediaTransportControls>(),
        winrt::put_abi(smtc));

    if (SUCCEEDED(hr)) {
      smtc_ = smtc;
    }
  } catch (const winrt::hresult_error& ex) {
    std::wcerr << L"SMTC init error: " << ex.message().c_str() << std::endl;
    return;
  }

  if (!smtc_) {
    std::cerr << "SMTC: Failed to get SystemMediaTransportControls" << std::endl;
    return;
  }

  // Configure controls (but start disabled - Dart will enable on first play)
  smtc_.IsEnabled(false);
  smtc_.IsPlayEnabled(true);
  smtc_.IsPauseEnabled(true);
  smtc_.IsNextEnabled(true);
  smtc_.IsPreviousEnabled(true);
  smtc_.IsStopEnabled(true);

  smtc_.PlaybackStatus(winrt::Windows::Media::MediaPlaybackStatus::Closed);

  // Listen for button presses.
  // These arrive on a background thread, so we PostMessage to the main thread.
  button_pressed_token_ = smtc_.ButtonPressed(
      [this](auto const& /*sender*/, auto const& args) {
        int button_id = static_cast<int>(args.Button());
        PostMessage(hwnd_, WM_SMTC_BUTTON_PRESSED,
                    static_cast<WPARAM>(button_id), 0);
      });

  initialized_ = true;
  std::cout << "SMTC: Initialized successfully!" << std::endl;
}

void SmtcHandler::Dispose() {
  if (!initialized_) return;

  try {
    if (smtc_) {
      smtc_.ButtonPressed(button_pressed_token_);
      smtc_.IsEnabled(false);
      smtc_ = nullptr;
    }
  } catch (...) {
  }

  if (channel_) {
    channel_->SetMethodCallHandler(nullptr);
    channel_ = nullptr;
  }

  initialized_ = false;
}

void SmtcHandler::SendButtonToFlutter(const std::string& button_name) {
  if (!channel_) return;

  channel_->InvokeMethod("buttonPressed",
      std::make_unique<flutter::EncodableValue>(button_name));
}

void SmtcHandler::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  const auto& method = call.method_name();

  if (method == "updateMetadata") {
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (args) {
      std::string title, artist, album, thumbnail;

      auto it = args->find(flutter::EncodableValue("title"));
      if (it != args->end()) {
        title = std::get<std::string>(it->second);
      }
      it = args->find(flutter::EncodableValue("artist"));
      if (it != args->end()) {
        artist = std::get<std::string>(it->second);
      }
      it = args->find(flutter::EncodableValue("album"));
      if (it != args->end()) {
        album = std::get<std::string>(it->second);
      }
      it = args->find(flutter::EncodableValue("thumbnail"));
      if (it != args->end()) {
        thumbnail = std::get<std::string>(it->second);
      }

      UpdateMetadata(title, artist, album, thumbnail);
      result->Success();
    } else {
      result->Error("INVALID_ARGS", "Expected map arguments");
    }
  } else if (method == "updatePlaybackStatus") {
    const auto* args = std::get_if<bool>(call.arguments());
    if (args) {
      UpdatePlaybackStatus(*args);
      result->Success();
    } else {
      result->Error("INVALID_ARGS", "Expected bool argument");
    }
  } else if (method == "setEnabled") {
    const auto* args = std::get_if<bool>(call.arguments());
    if (args) {
      SetEnabled(*args);
      result->Success();
    } else {
      result->Error("INVALID_ARGS", "Expected bool argument");
    }
  } else {
    result->NotImplemented();
  }
}

void SmtcHandler::SetThumbnailFromUrl(const std::string& url) {
  if (!smtc_ || url.empty()) return;

  try {
    // Convert std::string URL to a WinRT Uri
    // Use CreateFromUri — this is NON-BLOCKING.
    // Windows will fetch the image asynchronously in the background.
    std::wstring wide_url(url.begin(), url.end());
    winrt::hstring h_url{wide_url};
    winrt::Windows::Foundation::Uri uri{h_url};
    auto stream_ref = winrt::Windows::Storage::Streams::RandomAccessStreamReference::CreateFromUri(uri);

    auto updater = smtc_.DisplayUpdater();
    updater.Thumbnail(stream_ref);
    updater.Update();

    std::cout << "SMTC: Thumbnail set from URL" << std::endl;
  } catch (const winrt::hresult_error& ex) {
    std::wcerr << L"SMTC thumbnail error: " << ex.message().c_str() << std::endl;
  } catch (...) {
    std::cerr << "SMTC: Unknown error setting thumbnail" << std::endl;
  }
}

void SmtcHandler::UpdateMetadata(const std::string& title,
                                  const std::string& artist,
                                  const std::string& album,
                                  const std::string& thumbnail_url) {
  if (!smtc_) return;

  try {
    auto updater = smtc_.DisplayUpdater();
    updater.Type(winrt::Windows::Media::MediaPlaybackType::Music);

    auto music = updater.MusicProperties();
    music.Title(winrt::to_hstring(title));
    music.Artist(winrt::to_hstring(artist));
    if (!album.empty()) {
      music.AlbumTitle(winrt::to_hstring(album));
    }

    // Set or clear thumbnail
    if (thumbnail_url != last_thumbnail_url_) {
      last_thumbnail_url_ = thumbnail_url;
      if (!thumbnail_url.empty()) {
        // Set thumbnail from URL
        try {
          std::wstring wide_url(thumbnail_url.begin(), thumbnail_url.end());
          winrt::hstring h_url{wide_url};
          winrt::Windows::Foundation::Uri uri{h_url};
          auto stream_ref = winrt::Windows::Storage::Streams::RandomAccessStreamReference::CreateFromUri(uri);
          updater.Thumbnail(stream_ref);
        } catch (...) {
          // Thumbnail failed — still update the text metadata
        }
      } else {
        // Clear thumbnail (local video with no thumbnail)
        updater.Thumbnail(nullptr);
      }
    }

    updater.Update();
    std::cout << "SMTC: Metadata updated - " << title << std::endl;
  } catch (const winrt::hresult_error& ex) {
    std::wcerr << L"SMTC metadata error: " << ex.message().c_str() << std::endl;
  }
}

void SmtcHandler::UpdatePlaybackStatus(bool is_playing) {
  if (!smtc_) return;

  try {
    smtc_.PlaybackStatus(
        is_playing ? winrt::Windows::Media::MediaPlaybackStatus::Playing
                   : winrt::Windows::Media::MediaPlaybackStatus::Paused);
  } catch (...) {
  }
}

void SmtcHandler::SetEnabled(bool enabled) {
  if (!smtc_) return;

  try {
    smtc_.IsEnabled(enabled);
  } catch (...) {
  }
}
