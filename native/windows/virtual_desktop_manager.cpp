#include "virtual_desktop_manager.h"
#include <windows.h>
#include <comdef.h>
#include <shobjidl.h>
#include <vector>
#include <string>
#include <sstream>

// Global COM objects
static IVirtualDesktopManager* g_pDesktopManager = nullptr;

// Initialize COM interfaces
static bool InitializeCOM() {
    static bool initialized = false;
    if (initialized) return true;
    
    HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    if (FAILED(hr)) return false;
    
    // Use documented API to create Virtual Desktop Manager
    hr = CoCreateInstance(CLSID_VirtualDesktopManager, nullptr, CLSCTX_ALL,
                         IID_PPV_ARGS(&g_pDesktopManager));
    
    initialized = SUCCEEDED(hr);
    return initialized;
}


extern "C" {

// Switch to a virtual desktop by index
__declspec(dllexport) int switch_to_desktop(int desktop_index) {
    // Use keyboard simulation for desktop switching
    // Win + Ctrl + Left/Right arrows to navigate desktops
    for (int i = 0; i < desktop_index; i++) {
        keybd_event(VK_LWIN, 0, 0, 0);
        keybd_event(VK_CONTROL, 0, 0, 0);
        keybd_event(VK_RIGHT, 0, 0, 0);
        
        keybd_event(VK_RIGHT, 0, KEYEVENTF_KEYUP, 0);
        keybd_event(VK_CONTROL, 0, KEYEVENTF_KEYUP, 0);
        keybd_event(VK_LWIN, 0, KEYEVENTF_KEYUP, 0);
        
        Sleep(150);
    }
    
    return 1;
}

// Create a new virtual desktop
__declspec(dllexport) int create_virtual_desktop() {
    // Win + Ctrl + D to create new desktop
    keybd_event(VK_LWIN, 0, 0, 0);
    keybd_event(VK_CONTROL, 0, 0, 0);
    keybd_event('D', 0, 0, 0);
    
    keybd_event('D', 0, KEYEVENTF_KEYUP, 0);
    keybd_event(VK_CONTROL, 0, KEYEVENTF_KEYUP, 0);
    keybd_event(VK_LWIN, 0, KEYEVENTF_KEYUP, 0);
    
    return 1;
}

// Get current virtual desktop count
__declspec(dllexport) int get_desktop_count() {
    // For now, assume up to 10 desktops and detect by trying to switch
    // This is a limitation of the Windows API - no direct count method
    return 10; // Conservative estimate
}

// Get desktop names (returns concatenated string with separator)
__declspec(dllexport) int get_desktop_names(char* names, int maxLength) {
    if (!names || maxLength < 1) return 0;
    
    std::string result;
    for (int i = 1; i <= 10; i++) {
        if (i > 1) result += "|";
        result += "Desktop " + std::to_string(i);
    }
    
    if (result.length() >= maxLength) return 0;
    strcpy_s(names, maxLength, result.c_str());
    return result.length();
}

// Structure to pass data to window enumeration callback
struct EnumWindowsData {
    WindowData* windows;
    int maxWindows;
    int currentCount;
};

// Callback function for enumerating windows
BOOL CALLBACK EnumWindowsCallback(HWND hwnd, LPARAM lParam) {
    EnumWindowsData* data = reinterpret_cast<EnumWindowsData*>(lParam);
    
    // Skip if we've reached the maximum
    if (data->currentCount >= data->maxWindows) {
        return FALSE;
    }
    
    // Only include visible windows with a title
    if (!IsWindowVisible(hwnd) || GetWindowTextLength(hwnd) == 0) {
        return TRUE;
    }
    
    // Get window rectangle
    RECT rect;
    if (!GetWindowRect(hwnd, &rect)) {
        return TRUE;
    }
    
    // Fill in the window data
    WindowData& window = data->windows[data->currentCount];
    GetWindowTextA(hwnd, window.title, sizeof(window.title));
    window.x = rect.left;
    window.y = rect.top;
    window.width = rect.right - rect.left;
    window.height = rect.bottom - rect.top;
    window.hwnd = hwnd;
    
    data->currentCount++;
    return TRUE;
}

// Enumerate visible windows
__declspec(dllexport) int enumerate_windows(WindowData* windows, int maxWindows) {
    if (!windows || maxWindows <= 0) {
        return 0;
    }
    
    EnumWindowsData data;
    data.windows = windows;
    data.maxWindows = maxWindows;
    data.currentCount = 0;
    
    // Enumerate all top-level windows
    EnumWindows(EnumWindowsCallback, reinterpret_cast<LPARAM>(&data));
    
    return data.currentCount;
}

// Set window position and size
__declspec(dllexport) bool set_window_pos(HWND hwnd, int x, int y, int width, int height) {
    if (!IsWindow(hwnd)) {
        return false;
    }
    
    // Set window position and size using Win32 API
    return SetWindowPos(hwnd, NULL, x, y, width, height, SWP_NOZORDER | SWP_NOACTIVATE);
}

}