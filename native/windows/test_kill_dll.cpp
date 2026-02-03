// test_kill_dll.cpp
// Tests marcha_native.dll's kill_process_tree function with ConPTY
// Compile: cl /EHsc test_kill_dll.cpp /link kernel32.lib user32.lib

#include <windows.h>
#include <stdio.h>
#include <tlhelp32.h>
#include <vector>

// DLL function types
typedef intptr_t (*CreateJobForProcessFn)(DWORD processId);
typedef bool (*TerminateJobFn)(intptr_t jobHandle);
typedef bool (*KillProcessTreeFn)(DWORD rootProcessId);

void PrintTree(DWORD rootPid, int depth = 0) {
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) return;
    PROCESSENTRY32 pe;
    pe.dwSize = sizeof(pe);
    if (Process32First(snap, &pe)) {
        do {
            if (pe.th32ParentProcessID == rootPid && pe.th32ProcessID != rootPid) {
                for (int i = 0; i < depth; i++) printf("  ");
                printf("|- %ls (PID: %lu)\n", pe.szExeFile, pe.th32ProcessID);
                PrintTree(pe.th32ProcessID, depth + 1);
            }
        } while (Process32Next(snap, &pe));
    }
    CloseHandle(snap);
}

void GetAllDescendants(DWORD rootPid, std::vector<DWORD>& out) {
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) return;
    PROCESSENTRY32 pe;
    pe.dwSize = sizeof(pe);
    std::vector<DWORD> toVisit = {rootPid};
    while (!toVisit.empty()) {
        DWORD parent = toVisit.back();
        toVisit.pop_back();
        if (Process32First(snap, &pe)) {
            do {
                if (pe.th32ParentProcessID == parent && pe.th32ProcessID != rootPid) {
                    out.push_back(pe.th32ProcessID);
                    toVisit.push_back(pe.th32ProcessID);
                }
            } while (Process32Next(snap, &pe));
        }
    }
    CloseHandle(snap);
}

bool IsAlive(DWORD pid) {
    HANDLE h = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (!h) return false;
    DWORD code;
    GetExitCodeProcess(h, &code);
    CloseHandle(h);
    return code == STILL_ACTIVE;
}

int main(int argc, char* argv[]) {
    // Load marcha_native.dll
    HMODULE dll = LoadLibraryA("D:\\GSTPS_Proyectos\\marcha\\native\\windows\\build\\Release\\marcha_native.dll");
    if (!dll) {
        printf("[FAIL] Could not load marcha_native.dll: error %lu\n", GetLastError());
        return 1;
    }

    auto createJob = (CreateJobForProcessFn)GetProcAddress(dll, "create_job_for_process");
    auto terminateJob = (TerminateJobFn)GetProcAddress(dll, "terminate_job");
    auto killTree = (KillProcessTreeFn)GetProcAddress(dll, "kill_process_tree");

    if (!createJob || !terminateJob || !killTree) {
        printf("[FAIL] Could not find functions in DLL\n");
        return 1;
    }
    printf("[OK] Loaded marcha_native.dll, all functions found\n\n");

    // ====== TEST 1: kill_process_tree with ConPTY ======
    printf("=== TEST 1: kill_process_tree (NEW) with ConPTY ===\n");
    {
        HANDLE inR, inW, outR, outW;
        CreatePipe(&inR, &inW, NULL, 0);
        CreatePipe(&outR, &outW, NULL, 0);

        COORD size = {80, 24};
        HPCON hPty;
        CreatePseudoConsole(size, inR, outW, 0, &hPty);

        STARTUPINFOEXW si;
        ZeroMemory(&si, sizeof(si));
        si.StartupInfo.cb = sizeof(si);
        SIZE_T bytes;
        InitializeProcThreadAttributeList(NULL, 1, 0, &bytes);
        si.lpAttributeList = (PPROC_THREAD_ATTRIBUTE_LIST)malloc(bytes);
        InitializeProcThreadAttributeList(si.lpAttributeList, 1, 0, &bytes);
        UpdateProcThreadAttribute(si.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE, hPty, sizeof(hPty), NULL, NULL);

        PROCESS_INFORMATION pi;
        ZeroMemory(&pi, sizeof(pi));
        WCHAR cmd[] = L"cmd.exe";
        CreateProcessW(NULL, cmd, NULL, NULL, FALSE, EXTENDED_STARTUPINFO_PRESENT | CREATE_UNICODE_ENVIRONMENT, NULL, NULL, &si.StartupInfo, &pi);

        DWORD shellPid = pi.dwProcessId;
        printf("[1] ConPTY shell PID: %lu\n", shellPid);

        Sleep(500);
        // Send command that creates children
        const char* command = "ping -n 300 127.0.0.1\r\n";
        DWORD written;
        WriteFile(inW, command, (DWORD)strlen(command), &written, NULL);
        Sleep(2000);

        printf("[2] Process tree before kill:\n");
        printf("cmd.exe (PID: %lu)\n", shellPid);
        PrintTree(shellPid);

        std::vector<DWORD> descendants;
        GetAllDescendants(shellPid, descendants);

        printf("[3] Calling kill_process_tree(%lu)...\n", shellPid);
        bool result = killTree(shellPid);
        printf("    Returned: %s\n", result ? "true" : "false");

        ClosePseudoConsole(hPty);
        CloseHandle(inR); CloseHandle(inW);
        CloseHandle(outR); CloseHandle(outW);
        CloseHandle(pi.hThread);

        Sleep(500);
        printf("[4] Orphan check:\n");
        int orphans = 0;
        for (DWORD d : descendants) {
            if (IsAlive(d)) {
                printf("    [ORPHAN!] PID %lu alive\n", d);
                orphans++;
                HANDLE h = OpenProcess(PROCESS_TERMINATE, FALSE, d);
                if (h) { TerminateProcess(h, 1); CloseHandle(h); }
            } else {
                printf("    [DEAD]    PID %lu\n", d);
            }
        }
        printf("RESULT: %s\n\n", orphans ? "ORPHANS DETECTED" : "ALL CLEAN");
    }

    // ====== TEST 2: Deep tree with kill_process_tree ======
    printf("=== TEST 2: Deep tree (cmd -> cmd -> ping) with kill_process_tree ===\n");
    {
        HANDLE inR, inW, outR, outW;
        CreatePipe(&inR, &inW, NULL, 0);
        CreatePipe(&outR, &outW, NULL, 0);

        COORD size = {80, 24};
        HPCON hPty;
        CreatePseudoConsole(size, inR, outW, 0, &hPty);

        STARTUPINFOEXW si;
        ZeroMemory(&si, sizeof(si));
        si.StartupInfo.cb = sizeof(si);
        SIZE_T bytes;
        InitializeProcThreadAttributeList(NULL, 1, 0, &bytes);
        si.lpAttributeList = (PPROC_THREAD_ATTRIBUTE_LIST)malloc(bytes);
        InitializeProcThreadAttributeList(si.lpAttributeList, 1, 0, &bytes);
        UpdateProcThreadAttribute(si.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE, hPty, sizeof(hPty), NULL, NULL);

        PROCESS_INFORMATION pi;
        ZeroMemory(&pi, sizeof(pi));
        WCHAR cmd[] = L"cmd.exe";
        CreateProcessW(NULL, cmd, NULL, NULL, FALSE, EXTENDED_STARTUPINFO_PRESENT | CREATE_UNICODE_ENVIRONMENT, NULL, NULL, &si.StartupInfo, &pi);

        DWORD shellPid = pi.dwProcessId;
        printf("[1] ConPTY shell PID: %lu\n", shellPid);

        Sleep(500);
        // Nested: cmd -> cmd -> ping
        const char* command = "cmd.exe /c \"cmd.exe /c ping -n 300 127.0.0.1\"\r\n";
        DWORD written;
        WriteFile(inW, command, (DWORD)strlen(command), &written, NULL);
        Sleep(2000);

        printf("[2] Process tree before kill:\n");
        printf("cmd.exe (PID: %lu)\n", shellPid);
        PrintTree(shellPid);

        std::vector<DWORD> descendants;
        GetAllDescendants(shellPid, descendants);

        printf("[3] Calling kill_process_tree(%lu)...\n", shellPid);
        killTree(shellPid);

        ClosePseudoConsole(hPty);
        CloseHandle(inR); CloseHandle(inW);
        CloseHandle(outR); CloseHandle(outW);
        CloseHandle(pi.hThread);

        Sleep(500);
        printf("[4] Orphan check:\n");
        int orphans = 0;
        for (DWORD d : descendants) {
            if (IsAlive(d)) {
                printf("    [ORPHAN!] PID %lu alive\n", d);
                orphans++;
                HANDLE h = OpenProcess(PROCESS_TERMINATE, FALSE, d);
                if (h) { TerminateProcess(h, 1); CloseHandle(h); }
            } else {
                printf("    [DEAD]    PID %lu\n", d);
            }
        }
        printf("RESULT: %s\n\n", orphans ? "ORPHANS DETECTED" : "ALL CLEAN");
    }

    // ====== TEST 3: OLD METHOD (Job Object only) for comparison ======
    printf("=== TEST 3: OLD METHOD (Job Object only) - showing the bug ===\n");
    printf("Simulating what happens when DLL is NOT loaded (only _pty.kill)\n");
    {
        HANDLE inR, inW, outR, outW;
        CreatePipe(&inR, &inW, NULL, 0);
        CreatePipe(&outR, &outW, NULL, 0);

        COORD size2 = {80, 24};
        HPCON hPty;
        CreatePseudoConsole(size2, inR, outW, 0, &hPty);

        STARTUPINFOEXW si;
        ZeroMemory(&si, sizeof(si));
        si.StartupInfo.cb = sizeof(si);
        SIZE_T bytes;
        InitializeProcThreadAttributeList(NULL, 1, 0, &bytes);
        si.lpAttributeList = (PPROC_THREAD_ATTRIBUTE_LIST)malloc(bytes);
        InitializeProcThreadAttributeList(si.lpAttributeList, 1, 0, &bytes);
        UpdateProcThreadAttribute(si.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE, hPty, sizeof(hPty), NULL, NULL);

        PROCESS_INFORMATION pi;
        ZeroMemory(&pi, sizeof(pi));
        WCHAR cmd[] = L"cmd.exe";
        CreateProcessW(NULL, cmd, NULL, NULL, FALSE, EXTENDED_STARTUPINFO_PRESENT | CREATE_UNICODE_ENVIRONMENT, NULL, NULL, &si.StartupInfo, &pi);

        DWORD shellPid = pi.dwProcessId;
        printf("[1] ConPTY shell PID: %lu\n", shellPid);

        Sleep(500);
        const char* command = "ping -n 300 127.0.0.1\r\n";
        DWORD written;
        WriteFile(inW, command, (DWORD)strlen(command), &written, NULL);
        Sleep(2000);

        printf("[2] Process tree before kill:\n");
        printf("cmd.exe (PID: %lu)\n", shellPid);
        PrintTree(shellPid);

        std::vector<DWORD> descendants;
        GetAllDescendants(shellPid, descendants);

        // Simulate _pty.kill() ONLY (Process.killPid - no job, no tree walk)
        printf("[3] Killing ONLY the shell process (simulating _pty.kill() without DLL)...\n");
        HANDLE hKill = OpenProcess(PROCESS_TERMINATE, FALSE, shellPid);
        if (hKill) {
            TerminateProcess(hKill, 1);
            CloseHandle(hKill);
        }

        ClosePseudoConsole(hPty);
        CloseHandle(inR); CloseHandle(inW);
        CloseHandle(outR); CloseHandle(outW);
        CloseHandle(pi.hThread);

        Sleep(500);
        printf("[4] Orphan check:\n");
        int orphans = 0;
        for (DWORD d : descendants) {
            if (IsAlive(d)) {
                printf("    [ORPHAN!] PID %lu alive\n", d);
                orphans++;
                HANDLE h = OpenProcess(PROCESS_TERMINATE, FALSE, d);
                if (h) { TerminateProcess(h, 1); CloseHandle(h); }
            } else {
                printf("    [DEAD]    PID %lu\n", d);
            }
        }
        printf("RESULT: %s\n", orphans ? "ORPHANS DETECTED - THIS IS THE BUG" : "ALL CLEAN");
    }

    FreeLibrary(dll);
    printf("\n=== All tests complete ===\n");
    return 0;
}
