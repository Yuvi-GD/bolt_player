#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shobjidl.h>
#include <shlobj.h>
#include <propvarutil.h>
#include <propkey.h>
#include <wrl/client.h>

#include "flutter_window.h"
#include "utils.h"

#pragma comment(lib, "propsys.lib")

// The AppUserModelID must match everywhere: shortcut, SetCurrentProcess, etc.
static const wchar_t kAppUserModelId[] = L"com.boltplayer.BoltPlayer";
static const wchar_t kAppName[] = L"Bolt Player";

// Creates or updates a Start Menu shortcut (.lnk) with the AppUserModelID.
// Windows SMTC needs this shortcut to show the app name and icon in the
// media overlay for Win32 (non-UWP) desktop apps.
void EnsureStartMenuShortcut() {
  // Get the Start Menu Programs path
  wchar_t* programs_path = nullptr;
  HRESULT hr = SHGetKnownFolderPath(FOLDERID_Programs, 0, nullptr, &programs_path);
  if (FAILED(hr)) return;

  // Build shortcut path: Start Menu\Programs\Bolt Player.lnk
  std::wstring shortcut_path = std::wstring(programs_path) + L"\\Bolt Player.lnk";
  CoTaskMemFree(programs_path);

  // Get the path to the current executable
  wchar_t exe_path[MAX_PATH];
  GetModuleFileNameW(nullptr, exe_path, MAX_PATH);

  // Check if shortcut already exists and points to the right exe
  bool needs_create = true;
  if (GetFileAttributesW(shortcut_path.c_str()) != INVALID_FILE_ATTRIBUTES) {
    // Shortcut exists — verify it points to our exe and has correct AppUserModelID
    Microsoft::WRL::ComPtr<IShellLinkW> existing_link;
    hr = CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
                          IID_PPV_ARGS(&existing_link));
    if (SUCCEEDED(hr)) {
      Microsoft::WRL::ComPtr<IPersistFile> existing_file;
      hr = existing_link.As(&existing_file);
      if (SUCCEEDED(hr)) {
        hr = existing_file->Load(shortcut_path.c_str(), STGM_READ);
        if (SUCCEEDED(hr)) {
          wchar_t existing_exe[MAX_PATH];
          existing_link->GetPath(existing_exe, MAX_PATH, nullptr, 0);

          // Check if the shortcut has the correct AppUserModelID
          Microsoft::WRL::ComPtr<IPropertyStore> existing_store;
          hr = existing_link.As(&existing_store);
          if (SUCCEEDED(hr)) {
            PROPVARIANT pv;
            PropVariantInit(&pv);
            hr = existing_store->GetValue(PKEY_AppUserModel_ID, &pv);
            if (SUCCEEDED(hr) && pv.vt == VT_LPWSTR &&
                wcscmp(pv.pwszVal, kAppUserModelId) == 0 &&
                _wcsicmp(existing_exe, exe_path) == 0) {
              needs_create = false;  // Shortcut is up to date
            }
            PropVariantClear(&pv);
          }
        }
      }
    }
  }

  if (!needs_create) return;

  // Create the shortcut
  Microsoft::WRL::ComPtr<IShellLinkW> shell_link;
  hr = CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
                        IID_PPV_ARGS(&shell_link));
  if (FAILED(hr)) return;

  // Set target executable
  shell_link->SetPath(exe_path);

  // Set working directory
  wchar_t exe_dir[MAX_PATH];
  wcscpy_s(exe_dir, exe_path);
  PathRemoveFileSpecW(exe_dir);
  shell_link->SetWorkingDirectory(exe_dir);

  // Set description
  shell_link->SetDescription(kAppName);

  // Set icon (use the exe's embedded icon)
  shell_link->SetIconLocation(exe_path, 0);

  // Set the AppUserModelID property on the shortcut
  Microsoft::WRL::ComPtr<IPropertyStore> prop_store;
  hr = shell_link.As(&prop_store);
  if (SUCCEEDED(hr)) {
    PROPVARIANT pv;
    hr = InitPropVariantFromString(kAppUserModelId, &pv);
    if (SUCCEEDED(hr)) {
      prop_store->SetValue(PKEY_AppUserModel_ID, pv);
      prop_store->Commit();
      PropVariantClear(&pv);
    }
  }

  // Save the shortcut
  Microsoft::WRL::ComPtr<IPersistFile> persist_file;
  hr = shell_link.As(&persist_file);
  if (SUCCEEDED(hr)) {
    persist_file->Save(shortcut_path.c_str(), TRUE);
  }
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // Set App User Model ID so Windows shows the correct app name and icon
  // in SMTC (System Media Transport Controls) and the taskbar.
  ::SetCurrentProcessExplicitAppUserModelID(kAppUserModelId);

  // Create/update Start Menu shortcut with AppUserModelID.
  // Windows SMTC requires this to display the app name and icon.
  EnsureStartMenuShortcut();

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  // Create the window but don't show it yet.
  // The window_manager plugin will show it when ready.
  if (!window.Create(kAppName, origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
