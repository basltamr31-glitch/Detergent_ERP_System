#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <algorithm>
#include <iterator>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  std::vector<std::string> command_line_arguments = GetCommandLineArguments();
  const bool test_profile = std::find(command_line_arguments.begin(),
      command_line_arguments.end(), "--demo") != command_line_arguments.end();
  const wchar_t* window_title = test_profile
      ? L"Detergent Factory - TEST" : L"Detergent Factory";
  // Trial and business profiles use separate directories and instance guards.
  HANDLE app_mutex = ::CreateMutexW(
      nullptr, FALSE, test_profile
          ? L"Local\\DetergentFactoryERP.TestProfile.SingleInstance.v1"
          : L"Local\\DetergentFactoryERP.SingleInstance.v1");
  if (app_mutex == nullptr) {
    ::MessageBoxW(nullptr, L"Unable to initialize the application instance.",
                  L"Detergent Factory", MB_OK | MB_ICONERROR);
    return EXIT_FAILURE;
  }
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND existing_window = ::FindWindowW(nullptr, window_title);
    if (existing_window != nullptr) {
      ::ShowWindow(existing_window, SW_RESTORE);
      ::SetForegroundWindow(existing_window);
    } else {
      ::MessageBoxW(nullptr,
                    L"Detergent Factory is already starting or running. "
                    L"Use its existing window.",
                    L"Detergent Factory", MB_OK | MB_ICONINFORMATION);
    }
    ::CloseHandle(app_mutex);
    return EXIT_SUCCESS;
  }
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // Resolve assets from the executable, including shortcuts with another cwd.
  wchar_t executable_path[32768] = {};
  const DWORD path_length = ::GetModuleFileNameW(nullptr, executable_path,
                                                static_cast<DWORD>(std::size(executable_path)));
  if (path_length == 0 || path_length >= std::size(executable_path)) {
    ::MessageBoxW(nullptr, L"Unable to locate the application folder.",
                  window_title, MB_OK | MB_ICONERROR);
    ::CoUninitialize();
    ::CloseHandle(app_mutex);
    return EXIT_FAILURE;
  }
  const std::wstring executable(executable_path);
  const std::wstring data_path = executable.substr(0, executable.find_last_of(L"\\/")) + L"\\data";
  if (::GetFileAttributesW((data_path + L"\\flutter_assets").c_str()) == INVALID_FILE_ATTRIBUTES) {
    ::MessageBoxW(nullptr,
        L"The application data folder is missing. Extract the complete ERP ZIP, "
        L"then open START-TEST.cmd. Keep data and all DLLs beside the executable.",
        window_title, MB_OK | MB_ICONERROR);
    ::CoUninitialize();
    ::CloseHandle(app_mutex);
    return EXIT_FAILURE;
  }
  flutter::DartProject project(data_path);

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(window_title, origin, size)) {
    ::MessageBoxW(nullptr, L"Unable to start the ERP window. Extract the full package and retry.",
                  window_title, MB_OK | MB_ICONERROR);
    ::CoUninitialize();
    ::CloseHandle(app_mutex);
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  ::CloseHandle(app_mutex);
  return EXIT_SUCCESS;
}
