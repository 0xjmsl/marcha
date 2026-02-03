// test_kill_final.cpp - Definitive test with proper ConPTY timing
// Reads output to confirm shell is ready before sending commands

#include <windows.h>
#include <stdio.h>
#include <tlhelp32.h>
#include <vector>
#include <string>

typedef bool (*KillProcessTreeFn)(DWORD rootProcessId);

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

bool IsAlive(DWORD pid) {
    HANDLE h = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (!h) return false;
    DWORD code;
    GetExitCodeProcess(h, &code);
    CloseHandle(h);
    return code == STILL_ACTIVE;
}

// Read ConPTY output until we see the prompt
void WaitForPrompt(HANDLE outputReadSide) {
    char buf[4096];
    DWORD read;
    std::string accumulated;
    int attempts = 0;
    while (attempts < 20) { // max ~5 seconds
        DWORD avail = 0;
        PeekNamedPipe(outputReadSide, NULL, 0, NULL, &avail, NULL);
        if (avail > 0) {
            ReadFile(outputReadSide, buf, min(avail, sizeof(buf) - 1), &read, NULL);
            buf[read] = 0;
            accumulated += buf;
            // Look for ">" prompt
            if (accumulated.find(">") != std::string::npos) {
                return;
            }
        }
        Sleep(250);
        attempts++;
    }
}

// Drain any pending output
void DrainOutput(HANDLE outputReadSide) {
    char buf[4096];
    DWORD read;
    for (int i = 0; i < 8; i++) {
        DWORD avail = 0;
        PeekNamedPipe(outputReadSide, NULL, 0, NULL, &avail, NULL);
        if (avail > 0) {
            ReadFile(outputReadSide, buf, min(avail, sizeof(buf)), &read, NULL);
        }
        Sleep(250);
    }
}

struct ConPTYSession {
    HPCON hPty;
    HANDLE inR, inW, outR, outW;
    DWORD shellPid;
    HANDLE hProcess, hThread;
};

ConPTYSession CreateConPTYSession() {
    ConPTYSession s = {};
    CreatePipe(&s.inR, &s.inW, NULL, 0);
    CreatePipe(&s.outR, &s.outW, NULL, 0);

    COORD size = {80, 24};
    CreatePseudoConsole(size, s.inR, s.outW, 0, &s.hPty);

    STARTUPINFOEXW si;
    ZeroMemory(&si, sizeof(si));
    si.StartupInfo.cb = sizeof(si);
    SIZE_T bytes;
    InitializeProcThreadAttributeList(NULL, 1, 0, &bytes);
    si.lpAttributeList = (PPROC_THREAD_ATTRIBUTE_LIST)malloc(bytes);
    InitializeProcThreadAttributeList(si.lpAttributeList, 1, 0, &bytes);
    UpdateProcThreadAttribute(si.lpAttributeList, 0, PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE, s.hPty, sizeof(s.hPty), NULL, NULL);

    PROCESS_INFORMATION pi;
    ZeroMemory(&pi, sizeof(pi));
    WCHAR cmd[] = L"cmd.exe";
    CreateProcessW(NULL, cmd, NULL, NULL, FALSE,
        EXTENDED_STARTUPINFO_PRESENT | CREATE_UNICODE_ENVIRONMENT,
        NULL, NULL, &si.StartupInfo, &pi);

    s.shellPid = pi.dwProcessId;
    s.hProcess = pi.hProcess;
    s.hThread = pi.hThread;
    free(si.lpAttributeList);

    // Wait for shell prompt
    WaitForPrompt(s.outR);
    return s;
}

void CloseSession(ConPTYSession& s) {
    ClosePseudoConsole(s.hPty);
    CloseHandle(s.inR); CloseHandle(s.inW);
    CloseHandle(s.outR); CloseHandle(s.outW);
    CloseHandle(s.hThread);
    CloseHandle(s.hProcess);
}

int main() {
    HMODULE dll = LoadLibraryA("D:\\GSTPS_Proyectos\\marcha\\native\\windows\\build\\Release\\marcha_native.dll");
    if (!dll) {
        printf("[FAIL] Could not load DLL\n");
        return 1;
    }
    auto killTree = (KillProcessTreeFn)GetProcAddress(dll, "kill_process_tree");
    printf("[OK] DLL loaded, kill_process_tree found\n\n");

    // ====== TEST 1: kill_process_tree with running children ======
    printf("=== TEST 1: kill_process_tree with ConPTY children ===\n");
    {
        ConPTYSession s = CreateConPTYSession();
        printf("[1] Shell PID: %lu (prompt ready)\n", s.shellPid);

        // Send command
        const char* cmd = "ping -n 300 127.0.0.1\r\n";
        DWORD written;
        WriteFile(s.inW, cmd, (DWORD)strlen(cmd), &written, NULL);

        // Wait for ping to start
        DrainOutput(s.outR);

        printf("[2] Tree before kill:\n");
        printf("cmd.exe (PID: %lu)\n", s.shellPid);
        PrintTree(s.shellPid);

        std::vector<DWORD> desc;
        GetAllDescendants(s.shellPid, desc);
        printf("    Total descendants: %zu\n", desc.size());

        printf("[3] Calling kill_process_tree...\n");
        killTree(s.shellPid);

        CloseSession(s);
        Sleep(500);

        printf("[4] Orphan check:\n");
        int orphans = 0;
        for (DWORD d : desc) {
            if (IsAlive(d)) {
                printf("    [ORPHAN] PID %lu\n", d);
                orphans++;
                HANDLE h = OpenProcess(PROCESS_TERMINATE, FALSE, d);
                if (h) { TerminateProcess(h, 1); CloseHandle(h); }
            } else {
                printf("    [DEAD]   PID %lu\n", d);
            }
        }
        printf(">> %s <<\n\n", orphans ? "FAIL: ORPHANS" : "PASS: ALL CLEAN");
    }

    // ====== TEST 2: OLD METHOD reproduction (_pty.kill only) ======
    printf("=== TEST 2: OLD METHOD - _pty.kill() only (reproducing bug) ===\n");
    {
        ConPTYSession s = CreateConPTYSession();
        printf("[1] Shell PID: %lu (prompt ready)\n", s.shellPid);

        const char* cmd = "ping -n 300 127.0.0.1\r\n";
        DWORD written;
        WriteFile(s.inW, cmd, (DWORD)strlen(cmd), &written, NULL);
        DrainOutput(s.outR);

        printf("[2] Tree before kill:\n");
        printf("cmd.exe (PID: %lu)\n", s.shellPid);
        PrintTree(s.shellPid);

        std::vector<DWORD> desc;
        GetAllDescendants(s.shellPid, desc);
        printf("    Total descendants: %zu\n", desc.size());

        // OLD: only kill shell (what _pty.kill() / Process.killPid does)
        printf("[3] Killing ONLY shell process (like _pty.kill without DLL)...\n");
        HANDLE hKill = OpenProcess(PROCESS_TERMINATE, FALSE, s.shellPid);
        if (hKill) { TerminateProcess(hKill, 1); CloseHandle(hKill); }

        CloseSession(s);
        Sleep(500);

        printf("[4] Orphan check:\n");
        int orphans = 0;
        for (DWORD d : desc) {
            if (IsAlive(d)) {
                printf("    [ORPHAN] PID %lu\n", d);
                orphans++;
                HANDLE h = OpenProcess(PROCESS_TERMINATE, FALSE, d);
                if (h) { TerminateProcess(h, 1); CloseHandle(h); }
            } else {
                printf("    [DEAD]   PID %lu\n", d);
            }
        }
        printf(">> %s <<\n\n", orphans ? "FAIL: ORPHANS (BUG REPRODUCED)" : "PASS: ALL CLEAN");
    }

    FreeLibrary(dll);
    printf("=== Done ===\n");
    return 0;
}
