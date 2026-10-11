#include "flutter_window.h"

#include <optional>
#include <wincred.h>
#include <flutter/standard_method_codec.h>
#include "utils.h"

#include "flutter/generated_plugin_registrant.h"

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
  credential_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "erp/windows_credentials",
      &flutter::StandardMethodCodec::GetInstance());
  credential_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() != "prompt") {
          result->NotImplemented();
          return;
        }
        bool setup = false;
        if (call.arguments()) {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (args) {
            const auto it = args->find(flutter::EncodableValue("setup"));
            if (it != args->end()) {
              const auto* value = std::get_if<bool>(&it->second);
              if (value) setup = *value;
            }
          }
        }
        CREDUI_INFOW info = {};
        info.cbSize = sizeof(info);
        info.hwndParent = GetHandle();
        info.pszCaptionText = L"Detergent Factory ERP";
        info.pszMessageText = setup
            ? L"Create your local ERP owner account. Choose a username and a password of 12 to 128 characters. This is not your Windows account."
            : L"Enter your local ERP username and password. This is not your Windows account.";
        wchar_t username[CREDUI_MAX_USERNAME_LENGTH + 1] = {};
        wchar_t password[129] = {};
        BOOL save = FALSE;
        const DWORD status = ::CredUIPromptForCredentialsW(
            &info, L"DetergentFactoryERP", nullptr, 0, username,
            static_cast<ULONG>(std::size(username)), password,
            static_cast<ULONG>(std::size(password)), &save,
            CREDUI_FLAGS_GENERIC_CREDENTIALS | CREDUI_FLAGS_ALWAYS_SHOW_UI |
            CREDUI_FLAGS_DO_NOT_PERSIST | CREDUI_FLAGS_EXCLUDE_CERTIFICATES);
        if (status == NO_ERROR) {
          flutter::EncodableMap credentials;
          credentials[flutter::EncodableValue("name")] = flutter::EncodableValue(Utf8FromUtf16(username));
          credentials[flutter::EncodableValue("password")] = flutter::EncodableValue(Utf8FromUtf16(password));
          ::SecureZeroMemory(password, sizeof(password));
          result->Success(flutter::EncodableValue(credentials));
        } else {
          ::SecureZeroMemory(password, sizeof(password));
          if (status == ERROR_CANCELLED) result->Success();
          else result->Error("WINDOWS_CREDENTIALS", "Unable to open the Windows credential dialog: " + std::to_string(status));
        }
      });
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
  credential_channel_ = nullptr;
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
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
