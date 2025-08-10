#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <fstream>
#include <string>
#include <filesystem>

#include "flutter_window.h"
#include "utils.h"

static std::string GetLogPath() {
  char temp_path[MAX_PATH];
  DWORD temp_len = ::GetTempPathA(MAX_PATH, temp_path);
  return (temp_len > 0 ? std::string(temp_path) : std::string("")) + "InstalLauncher.log";
}

static void WriteLog(const std::string &line) {
  std::ofstream f(GetLogPath().c_str(), std::ios::app);
  if (f.is_open()) {
    f << line << std::endl;
  }
}

static bool FileExists(const std::filesystem::path &p) {
  std::error_code ec;
  return std::filesystem::exists(p, ec);
}

static std::string GetExeDir() {
  char exe_path[MAX_PATH];
  DWORD len = ::GetModuleFileNameA(nullptr, exe_path, MAX_PATH);
  std::filesystem::path p = std::filesystem::path(std::string(exe_path, len)).parent_path();
  return p.string();
}

static bool IsVC2015_2022RedistInstalled() {
  DWORD installed = 0; DWORD size = sizeof(DWORD);
  HKEY hKey;
  if (RegOpenKeyExA(HKEY_LOCAL_MACHINE, "SOFTWARE\\Microsoft\\VisualStudio\\14.0\\VC\\Runtimes\\x64", 0, KEY_READ | KEY_WOW64_64KEY, &hKey) == ERROR_SUCCESS) {
    RegQueryValueExA(hKey, "Installed", nullptr, nullptr, reinterpret_cast<LPBYTE>(&installed), &size);
    RegCloseKey(hKey);
    return installed == 1;
  }
  return false;
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  WriteLog("[launcher] starting wWinMain");
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  HRESULT init_result = ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  WriteLog(std::string("[launcher] CoInitializeEx result: 0x") + std::to_string((unsigned long long)init_result));

  // Environment diagnostics
  WriteLog(std::string("[launcher] exe dir: ") + GetExeDir());
  char cwd[MAX_PATH];
  if (_getcwd(cwd, MAX_PATH)) WriteLog(std::string("[launcher] cwd: ") + cwd);
  char* pathEnv = getenv("PATH");
  if (pathEnv) WriteLog(std::string("[launcher] PATH length: ") + std::to_string(strlen(pathEnv)));
  WriteLog(std::string("[launcher] VC++ redist installed: ") + (IsVC2015_2022RedistInstalled() ? "yes" : "no"));

  // Check key files exist next to EXE
  std::filesystem::path exeDir(GetExeDir());
  auto dllPath = exeDir / "flutter_windows.dll";
  auto icuPath = exeDir / "icudtl.dat";
  auto dataDir = exeDir / "data";
  WriteLog(std::string("[launcher] flutter_windows.dll exists: ") + (FileExists(dllPath) ? "yes" : "no"));
  WriteLog(std::string("[launcher] icudtl.dat exists: ") + (FileExists(icuPath) ? "yes" : "no"));
  WriteLog(std::string("[launcher] data dir exists: ") + (FileExists(dataDir) ? "yes" : "no"));

  // Try loading engine DLL explicitly to surface loader errors
  HMODULE dll = ::LoadLibraryA(dllPath.string().c_str());
  if (dll == nullptr) {
    DWORD err = ::GetLastError();
    WriteLog(std::string("[launcher] LoadLibrary flutter_windows.dll failed. GetLastError=") + std::to_string(err));
  } else {
    WriteLog("[launcher] LoadLibrary flutter_windows.dll OK");
    ::FreeLibrary(dll);
  }

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Instal", origin, size)) {
    WriteLog("[launcher] window.Create failed");
    return EXIT_FAILURE;
  }
  WriteLog("[launcher] window created");
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  WriteLog("[launcher] normal exit");
  return EXIT_SUCCESS;
}
