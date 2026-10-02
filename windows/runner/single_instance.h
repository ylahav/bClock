#ifndef RUNNER_SINGLE_INSTANCE_H_
#define RUNNER_SINGLE_INSTANCE_H_

#include <windows.h>

#include <string>
#include <vector>

// One bClock per executable path: a dev build and an installed build run
// side by side, but a second launch of the same exe (e.g. a scheduled alarm
// task's `--fire <id>`) is handed to the running instance instead.
class SingleInstance {
 public:
  // Takes the per-exe mutex. Returns false if another instance holds it.
  bool Acquire();

  // Sends |args| to the running instance's window and lets it take the
  // foreground. Waits briefly in case that instance is still starting.
  // Returns false if no window was found.
  bool ForwardToRunning(const std::vector<std::string>& args);

  // Tags |window| so a later launch can find it.
  void Mark(HWND window);

  // Removes the tag; call before |window| is destroyed.
  static void Unmark(HWND window);

  // WM_COPYDATA |dwData| identifying forwarded launch arguments.
  static constexpr ULONG_PTR kForwardedArgs = 0xB0C10C;

  // Decodes a WM_COPYDATA payload built by ForwardToRunning.
  static std::vector<std::string> DecodeArgs(const COPYDATASTRUCT& data);

 private:
  HANDLE mutex_ = nullptr;
};

#endif  // RUNNER_SINGLE_INSTANCE_H_
