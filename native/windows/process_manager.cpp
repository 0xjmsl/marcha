#include "process_manager.h"
#include <windows.h>
#include <string>
#include <vector>
#include <tlhelp32.h>

extern "C" {

// Helper function to find window by process ID and title fragment
static HWND FindWindowByProcessAndTitle(DWORD processId, const char* titleFragment) {
    struct EnumData {
        DWORD processId;
        const char* titleFragment;
        HWND foundWindow;
    };
    
    EnumData data = { processId, titleFragment, NULL };
    
    EnumWindows([](HWND hwnd, LPARAM lParam) -> BOOL {
        EnumData* pData = reinterpret_cast<EnumData*>(lParam);
        
        // Get process ID for this window
        DWORD windowProcessId;
        GetWindowThreadProcessId(hwnd, &windowProcessId);
        
        // Skip if not our process
        if (windowProcessId != pData->processId) {
            return TRUE; // Continue enumeration
        }
        
        // Skip if not visible
        if (!IsWindowVisible(hwnd)) {
            return TRUE;
        }
        
        // Get window title
        char title[256];
        if (GetWindowTextA(hwnd, title, sizeof(title)) == 0) {
            return TRUE;
        }
        
        // Check if title contains the fragment
        if (pData->titleFragment == nullptr || strstr(title, pData->titleFragment) != nullptr) {
            pData->foundWindow = hwnd;
            return FALSE; // Stop enumeration
        }
        
        return TRUE; // Continue enumeration
    }, reinterpret_cast<LPARAM>(&data));
    
    return data.foundWindow;
}

// Execute a command and return process ID
__declspec(dllexport) int execute_command(const char* command, const char* working_dir, int x, int y, int width, int height) {
    STARTUPINFOA si;
    PROCESS_INFORMATION pi;
    
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    ZeroMemory(&pi, sizeof(pi));
    
    // Create mutable copy of command
    std::string cmd(command);
    
    BOOL result = CreateProcessA(
        NULL,                   // No module name (use command line)
        &cmd[0],               // Command line
        NULL,                   // Process handle not inheritable
        NULL,                   // Thread handle not inheritable
        FALSE,                  // Set handle inheritance to FALSE
        0,                      // No special creation flags
        NULL,                   // Use parent's environment block
        working_dir,            // Working directory
        &si,                    // Pointer to STARTUPINFO structure
        &pi                     // Pointer to PROCESS_INFORMATION structure
    );
    
    if (result) {
        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);
        return pi.dwProcessId;
    }
    
    return 0;
}

// Execute command and position the resulting window
__declspec(dllexport) int execute_command_with_positioning(const char* command, const char* working_dir, 
    int x, int y, int width, int height, const char* windowTitleFragment, int timeoutMs) {
    
    // Launch the process first
    DWORD processId = execute_command(command, working_dir, -1, -1, -1, -1);
    if (processId == 0) {
        return 0;
    }
    
    // Wait for window to appear and position it
    HWND targetWindow = NULL;
    int attempts = 0;
    int maxAttempts = timeoutMs / 100; // Check every 100ms
    
    while (attempts < maxAttempts && targetWindow == NULL) {
        Sleep(100);
        targetWindow = FindWindowByProcessAndTitle(processId, windowTitleFragment);
        attempts++;
    }
    
    // Position the window if found
    if (targetWindow != NULL && x >= 0 && y >= 0 && width > 0 && height > 0) {
        SetWindowPos(targetWindow, NULL, x, y, width, height, SWP_NOZORDER | SWP_NOACTIVATE);
    }
    
    return processId;
}

// Open VS Code in a specific directory
__declspec(dllexport) int open_vscode(const char* directory) {
    std::string command = "code \"" + std::string(directory) + "\"";
    return execute_command(command.c_str(), directory, -1, -1, -1, -1);
}

// Open VS Code with positioning
__declspec(dllexport) int open_vscode_positioned(const char* directory, int x, int y, int width, int height) {
    std::string command = "code \"" + std::string(directory) + "\"";
    // Use directory name as window title fragment to identify the correct VS Code window
    std::string dirName = std::string(directory);
    size_t lastSlash = dirName.find_last_of("\\");
    if (lastSlash != std::string::npos) {
        dirName = dirName.substr(lastSlash + 1);
    }
    
    return execute_command_with_positioning(command.c_str(), directory, x, y, width, height, 
        dirName.c_str(), 5000); // 5 second timeout
}

// Execute command in existing VS Code terminal
__declspec(dllexport) int execute_in_vscode_terminal(const char* command, const char* directory) {
    std::string cmd = "code \"" + std::string(directory) + "\" --command \"workbench.action.terminal.sendSequence\" --args=\"" + std::string(command) + "\\r\"";
    return execute_command(cmd.c_str(), directory, -1, -1, -1, -1);
}

// Position an existing window by HWND
__declspec(dllexport) bool position_window_by_hwnd(HWND hwnd, int x, int y, int width, int height) {
    if (!IsWindow(hwnd)) {
        return false;
    }

    return SetWindowPos(hwnd, NULL, x, y, width, height, SWP_NOZORDER | SWP_NOACTIVATE) != FALSE;
}

// Send text to a window using simulated keystrokes
__declspec(dllexport) bool send_text_to_window(HWND hwnd, const char* text) {
    if (!IsWindow(hwnd)) {
        return false;
    }

    // Set focus to the window
    SetForegroundWindow(hwnd);
    SetFocus(hwnd);
    Sleep(100); // Small delay to ensure focus

    // Send each character
    size_t len = strlen(text);
    for (size_t i = 0; i < len; i++) {
        char c = text[i];

        if (c == '\r' || c == '\n') {
            // Send Enter key
            keybd_event(VK_RETURN, 0, 0, 0);
            keybd_event(VK_RETURN, 0, KEYEVENTF_KEYUP, 0);
        } else {
            // Convert character to virtual key and send
            SHORT vk = VkKeyScanA(c);
            BYTE virtualKey = LOBYTE(vk);
            BYTE shiftState = HIBYTE(vk);

            // Handle shift key
            if (shiftState & 1) {
                keybd_event(VK_SHIFT, 0, 0, 0);
            }

            keybd_event(virtualKey, 0, 0, 0);
            keybd_event(virtualKey, 0, KEYEVENTF_KEYUP, 0);

            if (shiftState & 1) {
                keybd_event(VK_SHIFT, 0, KEYEVENTF_KEYUP, 0);
            }
        }

        Sleep(10); // Small delay between keystrokes
    }

    return true;
}

// Find CMD window by title fragment
__declspec(dllexport) HWND find_cmd_window_by_title_fragment(const char* fragment) {
    struct EnumData {
        const char* fragment;
        HWND foundWindow;
    };

    EnumData data = { fragment, NULL };

    EnumWindows([](HWND hwnd, LPARAM lParam) -> BOOL {
        EnumData* pData = reinterpret_cast<EnumData*>(lParam);

        if (!IsWindowVisible(hwnd)) {
            return TRUE;
        }

        char title[256];
        char className[256];
        if (GetWindowTextA(hwnd, title, sizeof(title)) == 0) {
            return TRUE;
        }

        GetClassNameA(hwnd, className, sizeof(className));

        // Look for CMD windows (ConsoleWindowClass) or Windows Terminal
        if (strcmp(className, "ConsoleWindowClass") == 0 ||
            strcmp(className, "CASCADIA_HOSTING_WINDOW_CLASS") == 0) {

            if (pData->fragment == nullptr || strstr(title, pData->fragment) != nullptr) {
                pData->foundWindow = hwnd;
                return FALSE;
            }
        }

        return TRUE;
    }, reinterpret_cast<LPARAM>(&data));

    return data.foundWindow;
}

// Execute SSH session with automated password input and command execution
__declspec(dllexport) int execute_ssh_session(const char* host, const char* username, const char* password,
    int port, const char* remote_dir, const char* remote_command, int x, int y, int width, int height) {

    // Build the SSH command
    std::string sshCommand = "ssh ";
    if (port != 22) {
        sshCommand += "-p " + std::to_string(port) + " ";
    }
    sshCommand += std::string(username) + "@" + std::string(host);

    // Launch CMD with the SSH command
    std::string fullCommand = "cmd /k " + sshCommand;

    DWORD processId = execute_command(fullCommand.c_str(), nullptr, -1, -1, -1, -1);
    if (processId == 0) {
        return 0;
    }

    // Wait for CMD window to appear
    Sleep(1000);

    // Find the CMD window
    HWND cmdWindow = NULL;
    int attempts = 0;
    while (attempts < 50 && cmdWindow == NULL) { // 5 second timeout
        cmdWindow = find_cmd_window_by_title_fragment("cmd");
        if (cmdWindow == NULL) {
            Sleep(100);
            attempts++;
        }
    }

    if (cmdWindow == NULL) {
        return processId; // Return process ID even if we can't automate
    }

    // Position the window if coordinates provided
    if (x >= 0 && y >= 0 && width > 0 && height > 0) {
        position_window_by_hwnd(cmdWindow, x, y, width, height);
    }

    // Wait for SSH to prompt for password (usually takes 2-3 seconds)
    Sleep(3000);

    // Send the password
    std::string passwordWithEnter = std::string(password) + "\r";
    send_text_to_window(cmdWindow, passwordWithEnter.c_str());

    // Wait for login to complete
    Sleep(2000);

    // Navigate to remote directory if specified
    if (remote_dir != nullptr && strlen(remote_dir) > 0) {
        std::string cdCommand = "cd " + std::string(remote_dir) + "\r";
        send_text_to_window(cmdWindow, cdCommand.c_str());
        Sleep(500);
    }

    // Execute remote command if specified
    if (remote_command != nullptr && strlen(remote_command) > 0) {
        std::string command = std::string(remote_command) + "\r";
        send_text_to_window(cmdWindow, command.c_str());
    }

    return processId;
}

// Test basic CMD window opening
__declspec(dllexport) int test_cmd_window() {
    // Try to open a simple CMD window
    DWORD processId = execute_command("cmd /k echo Testing CMD window - type 'exit' to close", nullptr, -1, -1, -1, -1);
    return processId;
}

// Create a job object and assign a process to it
// Returns job handle as intptr_t (0 on failure)
__declspec(dllexport) intptr_t create_job_for_process(DWORD processId) {
    // Create an anonymous job object
    HANDLE hJob = CreateJobObjectA(NULL, NULL);
    if (hJob == NULL) {
        return 0;
    }

    // Configure the job to kill all processes when the job handle is closed
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION jobInfo = {0};
    jobInfo.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;

    if (!SetInformationJobObject(hJob, JobObjectExtendedLimitInformation, &jobInfo, sizeof(jobInfo))) {
        CloseHandle(hJob);
        return 0;
    }

    // Open a handle to the target process
    HANDLE hProcess = OpenProcess(PROCESS_SET_QUOTA | PROCESS_TERMINATE, FALSE, processId);
    if (hProcess == NULL) {
        CloseHandle(hJob);
        return 0;
    }

    // Assign the process to the job
    BOOL assigned = AssignProcessToJobObject(hJob, hProcess);
    CloseHandle(hProcess); // We no longer need the process handle

    if (!assigned) {
        // Process might already be in a job - this is not fatal
        // The job object will still work for any new child processes
        // that aren't breaking away from the job
    }

    return reinterpret_cast<intptr_t>(hJob);
}

// Terminate all processes in the job and close the handle
__declspec(dllexport) bool terminate_job(intptr_t jobHandle) {
    if (jobHandle == 0) {
        return false;
    }

    HANDLE hJob = reinterpret_cast<HANDLE>(jobHandle);

    // Terminate all processes in the job
    TerminateJobObject(hJob, 1);

    // Close the job handle (this also triggers KILL_ON_JOB_CLOSE)
    return CloseHandle(hJob) != FALSE;
}

// Check if SSH is available in the system
__declspec(dllexport) int check_ssh_available() {
    // Try to execute ssh with no arguments to see if it's available
    STARTUPINFOA si;
    PROCESS_INFORMATION pi;

    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_HIDE; // Hide the window
    ZeroMemory(&pi, sizeof(pi));

    // Create a command to test SSH availability - use ssh with no args
    // This will show usage and exit with 255, but it means SSH is available
    std::string testCommand = "ssh";

    BOOL result = CreateProcessA(
        NULL,
        &testCommand[0],
        NULL,
        NULL,
        FALSE,
        CREATE_NO_WINDOW, // Don't create a window
        NULL,
        NULL,
        &si,
        &pi
    );

    if (result) {
        // Wait for the process to complete (with timeout)
        DWORD waitResult = WaitForSingleObject(pi.hProcess, 5000); // 5 second timeout

        DWORD exitCode = 1; // Default to error
        if (waitResult == WAIT_OBJECT_0) {
            GetExitCodeProcess(pi.hProcess, &exitCode);
        }

        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);

        // SSH returns 255 when run with no args (showing usage), which means it's available
        // Only return 0 (not available) if the process couldn't be created or timed out
        return (waitResult == WAIT_OBJECT_0) ? 1 : 0;
    }

    return 0; // SSH not available
}

}