#ifndef PROCESS_MANAGER_H
#define PROCESS_MANAGER_H

#include <windows.h>

extern "C" {
    __declspec(dllexport) int execute_command(const char* command, const char* working_dir, int x, int y, int width, int height);
    __declspec(dllexport) int execute_command_with_positioning(const char* command, const char* working_dir, int x, int y, int width, int height, const char* windowTitleFragment, int timeoutMs);
    __declspec(dllexport) int open_vscode(const char* directory);
    __declspec(dllexport) int open_vscode_positioned(const char* directory, int x, int y, int width, int height);
    __declspec(dllexport) int execute_in_vscode_terminal(const char* command, const char* directory);
    __declspec(dllexport) bool position_window_by_hwnd(HWND hwnd, int x, int y, int width, int height);

    // SSH automation functions
    __declspec(dllexport) int execute_ssh_session(const char* host, const char* username, const char* password, int port, const char* remote_dir, const char* remote_command, int x, int y, int width, int height);
    __declspec(dllexport) bool send_text_to_window(HWND hwnd, const char* text);
    __declspec(dllexport) HWND find_cmd_window_by_title_fragment(const char* fragment);

    // Debug functions
    __declspec(dllexport) int test_cmd_window();
    __declspec(dllexport) int check_ssh_available();

    // Job object functions for process tree management
    __declspec(dllexport) intptr_t create_job_for_process(DWORD processId);
    __declspec(dllexport) bool terminate_job(intptr_t jobHandle);

    // Process tree kill - walks the process tree and terminates all descendants
    __declspec(dllexport) bool kill_process_tree(DWORD rootProcessId);
}

#endif // PROCESS_MANAGER_H