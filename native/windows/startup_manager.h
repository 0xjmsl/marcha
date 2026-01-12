#ifndef STARTUP_MANAGER_H
#define STARTUP_MANAGER_H

extern "C" {
    __declspec(dllexport) int add_to_startup(const char* app_name, const char* app_path);
    __declspec(dllexport) int remove_from_startup(const char* app_name);
    __declspec(dllexport) int is_in_startup(const char* app_name);
}

#endif // STARTUP_MANAGER_H