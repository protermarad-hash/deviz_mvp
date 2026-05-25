#include "flutter_window.h"

#include <commctrl.h>
#include <optional>

#include "flutter/generated_plugin_registrant.h"

#pragma comment(lib, "comctl32.lib")

namespace {

constexpr UINT_PTR kFlutterChildSubclassId = 1;

}  // namespace

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
  flutter_child_window_ = flutter_controller_->view()->GetNativeWindow();
  SetChildContent(flutter_child_window_);
  SetWindowSubclass(flutter_child_window_, ChildContentWindowProc,
                    kFlutterChildSubclassId,
                    reinterpret_cast<DWORD_PTR>(this));

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
  if (flutter_child_window_ != nullptr) {
    RemoveWindowSubclass(flutter_child_window_, ChildContentWindowProc,
                         kFlutterChildSubclassId);
    flutter_child_window_ = nullptr;
  }
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (TryForwardPenPointerAsMouse(hwnd, message, wparam, lparam)) {
    return 0;
  }

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

LRESULT CALLBACK FlutterWindow::ChildContentWindowProc(HWND hwnd,
                                                       UINT message,
                                                       WPARAM wparam,
                                                       LPARAM lparam,
                                                       UINT_PTR subclass_id,
                                                       DWORD_PTR ref_data) {
  auto* that = reinterpret_cast<FlutterWindow*>(ref_data);
  if (that == nullptr) {
    return DefSubclassProc(hwnd, message, wparam, lparam);
  }

  if (that->TryForwardPenPointerAsMouse(hwnd, message, wparam, lparam)) {
    return 0;
  }

  return DefSubclassProc(hwnd, message, wparam, lparam);
}

bool FlutterWindow::TryForwardPenPointerAsMouse(HWND hwnd,
                                                UINT message,
                                                WPARAM wparam,
                                                LPARAM lparam) {
  if (flutter_controller_ == nullptr) {
    return false;
  }

  switch (message) {
    case WM_POINTERDOWN:
    case WM_POINTERUP:
    case WM_POINTERUPDATE:
      break;
    default:
      return false;
  }

  const UINT32 pointer_id = GET_POINTERID_WPARAM(wparam);
  POINTER_INPUT_TYPE pointer_type = PT_POINTER;
  if (!GetPointerType(pointer_id, &pointer_type) || pointer_type != PT_PEN) {
    return false;
  }

  POINTER_INFO pointer_info;
  if (!GetPointerInfo(pointer_id, &pointer_info)) {
    return false;
  }

  POINT point = pointer_info.ptPixelLocation;
  const HWND target_window = flutter_child_window_ != nullptr
                                 ? flutter_child_window_
                                 : hwnd;
  ScreenToClient(target_window, &point);
  const LPARAM mouse_lparam = MAKELPARAM(point.x, point.y);

  UINT mouse_message = WM_MOUSEMOVE;
  WPARAM mouse_wparam = 0;

  switch (message) {
    case WM_POINTERDOWN:
      mouse_message = WM_LBUTTONDOWN;
      mouse_wparam = MK_LBUTTON;
      break;
    case WM_POINTERUP:
      mouse_message = WM_LBUTTONUP;
      mouse_wparam = 0;
      break;
    case WM_POINTERUPDATE:
      mouse_message = WM_MOUSEMOVE;
      mouse_wparam =
          (pointer_info.pointerFlags & POINTER_FLAG_INCONTACT) ? MK_LBUTTON : 0;
      break;
    default:
      return false;
  }

  SendMessage(target_window, mouse_message, mouse_wparam, mouse_lparam);
  return true;
}
