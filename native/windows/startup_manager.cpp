#include "startup_manager.h"
#include <windows.h>
#include <shlobj.h>
#include <string>

extern "C" {

// Add application to Windows startup
__declspec(dllexport) int add_to_startup(const char* app_name, const char* app_path) {
    HKEY hkey;
    LONG result = RegOpenKeyExA(HKEY_CURRENT_USER, 
        "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run", 
        0, KEY_SET_VALUE, &hkey);
    
    if (result != ERROR_SUCCESS) {
        return 0;
    }
    
    result = RegSetValueExA(hkey, app_name, 0, REG_SZ, 
        (const BYTE*)app_path, strlen(app_path) + 1);
    
    RegCloseKey(hkey);
    return result == ERROR_SUCCESS ? 1 : 0;
}

// Remove application from Windows startup
__declspec(dllexport) int remove_from_startup(const char* app_name) {
    HKEY hkey;
    LONG result = RegOpenKeyExA(HKEY_CURRENT_USER, 
        "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run", 
        0, KEY_SET_VALUE, &hkey);
    
    if (result != ERROR_SUCCESS) {
        return 0;
    }
    
    result = RegDeleteValueA(hkey, app_name);
    RegCloseKey(hkey);
    return result == ERROR_SUCCESS ? 1 : 0;
}

// Check if application is in startup
__declspec(dllexport) int is_in_startup(const char* app_name) {
    HKEY hkey;
    LONG result = RegOpenKeyExA(HKEY_CURRENT_USER, 
        "SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run", 
        0, KEY_QUERY_VALUE, &hkey);
    
    if (result != ERROR_SUCCESS) {
        return 0;
    }
    
    DWORD type;
    DWORD size = 0;
    result = RegQueryValueExA(hkey, app_name, NULL, &type, NULL, &size);
    
    RegCloseKey(hkey);
    return result == ERROR_SUCCESS ? 1 : 0;
}

}