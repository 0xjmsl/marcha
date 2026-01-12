#ifndef VIRTUAL_DESKTOP_MANAGER_H
#define VIRTUAL_DESKTOP_MANAGER_H

#include <windows.h>

// Window information structure
struct WindowData {
    char title[256];
    int x;
    int y;
    int width;
    int height;
    HWND hwnd;
};

extern "C" {
    // Existing functions
    __declspec(dllexport) int switch_to_desktop(int desktop_index);
    __declspec(dllexport) int create_virtual_desktop();
    __declspec(dllexport) int get_desktop_count();
    
    // New enhanced functions
    __declspec(dllexport) int get_desktop_names(char* names, int maxLength);
    
    // Window enumeration functions
    __declspec(dllexport) int enumerate_windows(WindowData* windows, int maxWindows);
    __declspec(dllexport) bool set_window_pos(HWND hwnd, int x, int y, int width, int height);
}

#endif // VIRTUAL_DESKTOP_MANAGER_H