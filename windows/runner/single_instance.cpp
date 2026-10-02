#include "single_instance.h"

#include <cwctype>

namespace {

// Window property holding the instance key, so we only ever message a
// bClock window from the same exe, not any Flutter runner window.
constexpr wchar_t kInstanceProp[] = L"bClock.InstanceKey";
constexpr wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

// FNV-1a over the lower-cased exe path. Stable across processes, unlike
// pointer or atom values.
ULONG_PTR InstanceKey() {
  wchar_t path[MAX_PATH];
  DWORD length = ::GetModuleFileNameW(nullptr, path, MAX_PATH);
  ULONG_PTR hash = static_cast<ULONG_PTR>(1469598103934665603ull);
  for (DWORD i = 0; i < length; ++i) {
    hash ^= static_cast<ULONG_PTR>(std::towlower(path[i]));
    hash *= static_cast<ULONG_PTR>(1099511628211ull);
  }
  // Zero would read as "no property".
  return hash ? hash : 1;
}

struct FindContext {
  ULONG_PTR key;
  HWND found;
};

BOOL CALLBACK FindInstanceWindow(HWND window, LPARAM lparam) {
  auto* context = reinterpret_cast<FindContext*>(lparam);
  wchar_t class_name[64];
  if (::GetClassNameW(window, class_name, 64) &&
      wcscmp(class_name, kWindowClassName) == 0 &&
      reinterpret_cast<ULONG_PTR>(::GetPropW(window, kInstanceProp)) ==
          context->key) {
    context->found = window;
    return FALSE;
  }
  return TRUE;
}

}  // namespace

bool SingleInstance::Acquire() {
  wchar_t name[64];
  swprintf_s(name, L"Local\\bClock.%llx",
             static_cast<unsigned long long>(InstanceKey()));
  // Held for the life of the process; Windows releases it on exit.
  mutex_ = ::CreateMutexW(nullptr, TRUE, name);
  return mutex_ != nullptr && ::GetLastError() != ERROR_ALREADY_EXISTS;
}

bool SingleInstance::ForwardToRunning(const std::vector<std::string>& args) {
  FindContext context{InstanceKey(), nullptr};
  // The other instance may hold the mutex but not have its window yet.
  for (int attempt = 0; attempt < 50 && !context.found; ++attempt) {
    if (attempt > 0) ::Sleep(100);
    ::EnumWindows(FindInstanceWindow, reinterpret_cast<LPARAM>(&context));
  }
  if (!context.found) return false;

  // We may hold the foreground right (the user launched us); pass it on.
  DWORD process_id = 0;
  ::GetWindowThreadProcessId(context.found, &process_id);
  ::AllowSetForegroundWindow(process_id);

  // Arguments as UTF-8, each terminated by '\0'.
  std::string payload;
  for (const auto& arg : args) {
    payload += arg;
    payload.push_back('\0');
  }
  COPYDATASTRUCT data{};
  data.dwData = kForwardedArgs;
  data.cbData = static_cast<DWORD>(payload.size());
  data.lpData = payload.data();
  DWORD_PTR result = 0;
  return ::SendMessageTimeoutW(context.found, WM_COPYDATA, 0,
                               reinterpret_cast<LPARAM>(&data),
                               SMTO_ABORTIFHUNG, 5000, &result) != 0;
}

void SingleInstance::Mark(HWND window) {
  ::SetPropW(window, kInstanceProp, reinterpret_cast<HANDLE>(InstanceKey()));
}

void SingleInstance::Unmark(HWND window) {
  ::RemovePropW(window, kInstanceProp);
}

std::vector<std::string> SingleInstance::DecodeArgs(
    const COPYDATASTRUCT& data) {
  std::vector<std::string> args;
  const char* bytes = static_cast<const char*>(data.lpData);
  std::string current;
  for (DWORD i = 0; i < data.cbData; ++i) {
    if (bytes[i] == '\0') {
      args.push_back(std::move(current));
      current.clear();
    } else {
      current.push_back(bytes[i]);
    }
  }
  return args;
}
