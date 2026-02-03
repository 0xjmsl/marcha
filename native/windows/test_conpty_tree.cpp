// test_conpty_tree.cpp - Understand ConPTY process tree + test kill
#include <windows.h>
#include <stdio.h>
#include <tlhelp32.h>
#include <vector>
#include <string>

typedef bool (*KillProcessTreeFn)(DWORD rootProcessId);

void WaitForPrompt(HANDLE outR) {
    char buf[4096];
    DWORD readBytes;
    std::string acc;
    for (int i = 0; i < 20; i++) {
        DWORD avail = 0;
        PeekNamedPipe(outR, NULL, 0, NULL, &avail, NULL);
        if (avail > 0) {
            ReadFile(outR, buf, min(avail, (DWORD)sizeof(buf) - 1), &readBytes, NULL);
            buf[readBytes] = 0;
            acc += buf;
            if (acc.find(">") != std::string::npos) return;
        }
        Sleep(250);
    }
}

void Drain(HANDLE outR, int ms) {
    char buf[4096]; DWORD readBytes; int elapsed = 0;
    while (elapsed < ms) {
        DWORD avail = 0;
        PeekNamedPipe(outR, NULL, 0, NULL, &avail, NULL);
        if (avail > 0) ReadFile(outR, buf, min(avail, (DWORD)sizeof(buf)), &readBytes, NULL);
        Sleep(100); elapsed += 100;
    }
}

bool IsAlive(DWORD pid) {
    HANDLE h = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (!h) return false;
    DWORD code; GetExitCodeProcess(h, &code); CloseHandle(h);
    return code == STILL_ACTIVE;
}

void PrintFullTree(DWORD rootPid, int depth = 0) {
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) return;
    PROCESSENTRY32 pe; pe.dwSize = sizeof(pe);
    if (Process32First(snap, &pe)) {
        do {
            if (pe.th32ParentProcessID == rootPid && pe.th32ProcessID != rootPid) {
                for (int i = 0; i < depth; i++) printf("  ");
                printf("|- %s (PID: %lu)\n", pe.szExeFile, pe.th32ProcessID);
                PrintFullTree(pe.th32ProcessID, depth + 1);
            }
        } while (Process32Next(snap, &pe));
    }
    CloseHandle(snap);
}

void GetAllDescendants(DWORD rootPid, std::vector<DWORD>& out) {
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) return;
    std::vector<DWORD> toVisit = {rootPid};
    while (!toVisit.empty()) {
        DWORD parent = toVisit.back(); toVisit.pop_back();
        PROCESSENTRY32 pe; pe.dwSize = sizeof(pe);
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

void FindProcess(const char* name) {
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) return;
    PROCESSENTRY32 pe; pe.dwSize = sizeof(pe);
    if (Process32First(snap, &pe)) {
        do {
            if (_stricmp(pe.szExeFile, name) == 0) {
                printf("  %s PID=%lu Parent=%lu\n", pe.szExeFile, pe.th32ProcessID, pe.th32ParentProcessID);
            }
        } while (Process32Next(snap, &pe));
    }
    CloseHandle(snap);
}

int main() {
    HMODULE dll = LoadLibraryA("D:\\GSTPS_Proyectos\\marcha\\native\\windows\\build\\Release\\marcha_native.dll");
    auto killTree = dll ? (KillProcessTreeFn)GetProcAddress(dll, "kill_process_tree") : nullptr;
    printf("DLL loaded: %s, killTree: %s\n\n", dll ? "yes" : "no", killTree ? "yes" : "no");

    DWORD thisPid = GetCurrentProcessId();

    // Create ConPTY
    HANDLE inR, inW, outR, outW;
    CreatePipe(&inR, &inW, NULL, 0);
    CreatePipe(&outR, &outW, NULL, 0);
    COORD sz = {80, 24}; HPCON hPty;
    CreatePseudoConsole(sz, inR, outW, 0, &hPty);

    STARTUPINFOEXW si; ZeroMemory(&si, sizeof(si));
    si.StartupInfo.cb = sizeof(si);
    SIZE_T bytes;
    InitializeProcThreadAttributeList(NULL, 1, 0, &bytes);
    si.lpAttributeList = (PPROC_THREAD_ATTRIBUTE_LIST)malloc(bytes);
    InitializeProcThreadAttributeList(si.lpAttributeList, 1, 0, &bytes);
    UpdateProcThreadAttribute(si.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE, hPty, sizeof(hPty), NULL, NULL);

    PROCESS_INFORMATION pi; ZeroMemory(&pi, sizeof(pi));
    WCHAR cmd[] = L"cmd.exe";
    CreateProcessW(NULL, cmd, NULL, NULL, FALSE,
        EXTENDED_STARTUPINFO_PRESENT | CREATE_UNICODE_ENVIRONMENT,
        NULL, NULL, &si.StartupInfo, &pi);
    DWORD shellPid = pi.dwProcessId;
    printf("This PID: %lu, Shell PID: %lu\n", thisPid, shellPid);
    free(si.lpAttributeList);

    WaitForPrompt(outR);
    printf("Shell ready.\n\n");

    printf("--- BEFORE command ---\n");
    printf("Tree from this process:\n");
    printf("test_conpty_tree.exe (PID: %lu)\n", thisPid);
    PrintFullTree(thisPid);

    // Send ping command
    const char* pingCmd = "ping -n 300 127.0.0.1\r\n";
    DWORD written;
    WriteFile(inW, pingCmd, (DWORD)strlen(pingCmd), &written, NULL);
    printf("\nSent: ping -n 300 127.0.0.1\nWaiting 3s for child processes...\n");
    Drain(outR, 3000);

    printf("\n--- AFTER command ---\n");
    printf("All PING.EXE in system:\n");
    FindProcess("PING.EXE");

    printf("\nTree from this process:\n");
    printf("test_conpty_tree.exe (PID: %lu)\n", thisPid);
    PrintFullTree(thisPid);

    printf("\nTree from shell:\n");
    printf("cmd.exe (PID: %lu)\n", shellPid);
    PrintFullTree(shellPid);

    // Collect descendants
    std::vector<DWORD> shellDesc, thisDesc;
    GetAllDescendants(shellPid, shellDesc);
    GetAllDescendants(thisPid, thisDesc);
    printf("\nShell descendants: %zu\n", shellDesc.size());
    printf("This process descendants: %zu\n", thisDesc.size());

    // === TEST A: kill_process_tree on shell PID ===
    printf("\n=== KILLING with kill_process_tree(%lu) ===\n", shellPid);
    if (killTree) killTree(shellPid);

    Sleep(500);

    printf("\nPING.EXE after kill:\n");
    FindProcess("PING.EXE");

    printf("\nShell descendants:\n");
    int orphans = 0;
    for (DWORD d : shellDesc) {
        bool alive = IsAlive(d);
        printf("  PID %lu: %s\n", d, alive ? "ORPHAN!" : "dead");
        if (alive) orphans++;
    }
    printf("This-process descendants:\n");
    for (DWORD d : thisDesc) {
        bool alive = IsAlive(d);
        printf("  PID %lu: %s\n", d, alive ? "ALIVE" : "dead");
        if (alive && d != GetCurrentProcessId()) {
            // Clean up
            HANDLE h = OpenProcess(PROCESS_TERMINATE, FALSE, d);
            if (h) { TerminateProcess(h, 1); CloseHandle(h); }
        }
    }

    printf("\n>> Shell orphans: %d <<\n", orphans);

    ClosePseudoConsole(hPty);
    CloseHandle(inR); CloseHandle(inW); CloseHandle(outR); CloseHandle(outW);
    CloseHandle(pi.hThread); CloseHandle(pi.hProcess);
    if (dll) FreeLibrary(dll);
    return 0;
}
