#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <fstream>
#include <string>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Basic launcher logging to help diagnose startup issues on user machines.
  // Writes to the user's temp directory: %TEMP%\\InstalLauncher.log
  char temp_path[MAX_PATH];
  DWORD temp_len = ::GetTempPathA(MAX_PATH, temp_path);
  std::string log_path = (temp_len > 0 ? std::string(temp_path) : std::string("")) + "InstalLauncher.log";
  std::ofstream launcher_log;
  launcher_log.open(log_path.c_str(), std::ios::app);
  if (launcher_log.is_open()) {
    launcher_log << "[launcher] starting wWinMain" << std::endl;
  }
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  HRESULT init_result = ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  if (launcher_log.is_open()) {
    launcher_log << "[launcher] CoInitializeEx result: " << std::hex << init_result << std::endl;
  }

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Instal", origin, size)) {
    if (launcher_log.is_open()) {
      launcher_log << "[launcher] window.Create failed" << std::endl;
      launcher_log.close();
    }
    return EXIT_FAILURE;
  }
  if (launcher_log.is_open()) {
    launcher_log << "[launcher] window created" << std::endl;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (launcher_log.is_open()) {
    launcher_log << "[launcher] normal exit" << std::endl;
    launcher_log.close();
  }
  return EXIT_SUCCESS;
}
