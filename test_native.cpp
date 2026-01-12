#include <windows.h>
#include <iostream>

// Function signatures from our DLL
typedef int (*GetDesktopNamesFunc)(char* names, int maxLength);
typedef int (*EnumerateWindowsFunc)(void* windows, int maxWindows);

int main() {
    std::cout << "Testing marcha_native.dll..." << std::endl;
    
    // Load our DLL
    HMODULE hDll = LoadLibraryA("marcha_native.dll");
    if (!hDll) {
        std::cerr << "Failed to load marcha_native.dll. Error: " << GetLastError() << std::endl;
        return 1;
    }
    
    std::cout << "DLL loaded successfully!" << std::endl;
    
    // Test get_desktop_names function
    GetDesktopNamesFunc getDesktopNames = (GetDesktopNamesFunc)GetProcAddress(hDll, "get_desktop_names");
    if (getDesktopNames) {
        char names[1024] = {0};
        int result = getDesktopNames(names, 1024);
        std::cout << "get_desktop_names returned: " << result << std::endl;
        std::cout << "Desktop names: " << names << std::endl;
    } else {
        std::cerr << "get_desktop_names function not found" << std::endl;
    }
    
    FreeLibrary(hDll);
    std::cout << "Test completed." << std::endl;
    return 0;
}