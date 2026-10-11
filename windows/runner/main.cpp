#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // All portable copies share the same per-user Hive database. Only one
  // process may open it; bring the existing window forward on a second launch.
  HANDLE app_mutex = ::CreateMutexW(
      nullptr, FALSE, L"Local\\DetergentFactoryERP.SingleInstance.v1");
  if (app_mutex == nullptr) {
    ::MessageBoxW(nullptr, L"Unable to initialize the application instance.",
                  L"Detergent Factory", MB_OK | MB_ICONERROR);
    return EXIT_FAILURE;
  }
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND existing_window = ::FindWindowW(nullptr, L"Detergent Factory");
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

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Detergent Factory", origin, size)) {
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
