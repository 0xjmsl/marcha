// test_kill.cpp
// Replicates the exact Marcha flow: ConPTY -> Job Object -> Kill
// Compile: cl /EHsc test_kill.cpp /link kernel32.lib user32.lib
//
// Usage:
//   test_kill.exe           (test TerminateJobObject approach)
//   test_kill.exe tree      (test process tree walk approach)

#include <windows.h>
#include <stdio.h>
#include <tlhelp32.h>
#include <vector>

// ============================================================
// Process tree enumeration (the proposed fix)
// ============================================================
void GetDescendants(DWORD parentPid, std::vector<DWORD>& out) {
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) return;

    PROCESSENTRY32 pe;
    pe.dwSize = sizeof(pe);

    if (Process32First(snap, &pe)) {
        do {
            if (pe.th32ParentProcessID == parentPid && pe.th32ProcessID != parentPid) {
                out.push_back(pe.th32ProcessID);
                GetDescendants(pe.th32ProcessID, out);
            }
        } while (Process32Next(snap, &pe));
    }
    CloseHandle(snap);
}

bool KillProcessTree(DWORD rootPid) {
    std::vector<DWORD> descendants;
    GetDescendants(rootPid, descendants);

    printf("[TREE-KILL] Found %zu descendants of PID %lu\n", descendants.size(), rootPid);

    // Kill deepest first (reverse order)
    bool allKilled = true;
    for (int i = (int)descendants.size() - 1; i >= 0; i--) {
        HANDLE h = OpenProcess(PROCESS_TERMINATE, FALSE, descendants[i]);
        if (h) {
            if (TerminateProcess(h, 1)) {
                printf("[TREE-KILL]   Killed PID %lu\n", descendants[i]);
            } else {
                printf("[TREE-KILL]   Failed to kill PID %lu: error %lu\n", descendants[i], GetLastError());
                allKilled = false;
            }
            CloseHandle(h);
        } else {
            printf("[TREE-KILL]   Couldn't open PID %lu (already dead?): error %lu\n", descendants[i], GetLastError());
        }
    }

    // Kill root
    HANDLE hRoot = OpenProcess(PROCESS_TERMINATE, FALSE, rootPid);
    if (hRoot) {
        TerminateProcess(hRoot, 1);
        CloseHandle(hRoot);
        printf("[TREE-KILL]   Killed root PID %lu\n", rootPid);
    }
    return allKilled;
}

// ============================================================
// Check which processes are still alive
// ============================================================
void PrintProcessTree(DWORD rootPid, int depth = 0) {
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) return;

    PROCESSENTRY32 pe;
    pe.dwSize = sizeof(pe);

    if (Process32First(snap, &pe)) {
        do {
            if (pe.th32ParentProcessID == rootPid && pe.th32ProcessID != rootPid) {
                for (int i = 0; i < depth; i++) printf("  ");
                printf("|- %ls (PID: %lu)\n", pe.szExeFile, pe.th32ProcessID);
                PrintProcessTree(pe.th32ProcessID, depth + 1);
            }
        } while (Process32Next(snap, &pe));
    }
    CloseHandle(snap);
}

bool IsProcessAlive(DWORD pid) {
    HANDLE h = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (!h) return false;
    DWORD exitCode;
    GetExitCodeProcess(h, &exitCode);
    CloseHandle(h);
    return (exitCode == STILL_ACTIVE);
}

void CheckOrphans(const std::vector<DWORD>& pids) {
    int orphanCount = 0;
    for (DWORD pid : pids) {
        if (IsProcessAlive(pid)) {
            printf("  [ORPHAN!] PID %lu is STILL RUNNING\n", pid);
            orphanCount++;
        } else {
            printf("  [DEAD]    PID %lu terminated\n", pid);
        }
    }
    if (orphanCount > 0) {
        printf("\n  >> %d ORPHANS DETECTED <<\n", orphanCount);
    } else {
        printf("\n  >> ALL CLEAN - no orphans <<\n");
    }
}

// ============================================================
// ConPTY setup (replicates flutter_pty_win.c pty_create)
// ============================================================
int main(int argc, char* argv[]) {
    bool useTreeKill = (argc > 1 && strcmp(argv[1], "tree") == 0);

    printf("=== Marcha Process Kill Test (ConPTY) ===\n");
    printf("Mode: %s\n\n", useTreeKill ? "PROCESS TREE WALK" : "JOB OBJECT (current Marcha code)");

    // Step 1: Create ConPTY (exactly like flutter_pty_win.c)
    HANDLE inputReadSide, inputWriteSide;
    HANDLE outputReadSide, outputWriteSide;

    CreatePipe(&inputReadSide, &inputWriteSide, NULL, 0);
    CreatePipe(&outputReadSide, &outputWriteSide, NULL, 0);

    COORD size = {80, 24};
    HPCON hPty;
    HRESULT hr = CreatePseudoConsole(size, inputReadSide, outputWriteSide, 0, &hPty);
    if (FAILED(hr)) {
        printf("[ERROR] CreatePseudoConsole failed: 0x%08lX\n", hr);
        return 1;
    }
    printf("[1] Created ConPTY\n");

    // Step 2: Create process with ConPTY (exactly like flutter_pty_win.c)
    STARTUPINFOEXW startupInfo;
    ZeroMemory(&startupInfo, sizeof(startupInfo));
    startupInfo.StartupInfo.cb = sizeof(startupInfo);
    startupInfo.StartupInfo.dwFlags = STARTF_USESTDHANDLES;

    SIZE_T bytesRequired;
    InitializeProcThreadAttributeList(NULL, 1, 0, &bytesRequired);
    startupInfo.lpAttributeList = (PPROC_THREAD_ATTRIBUTE_LIST)malloc(bytesRequired);
    InitializeProcThreadAttributeList(startupInfo.lpAttributeList, 1, 0, &bytesRequired);

    UpdateProcThreadAttribute(startupInfo.lpAttributeList, 0,
        PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE, hPty, sizeof(hPty), NULL, NULL);

    PROCESS_INFORMATION processInfo;
    ZeroMemory(&processInfo, sizeof(processInfo));

    WCHAR cmd[] = L"cmd.exe";
    BOOL ok = CreateProcessW(NULL, cmd, NULL, NULL, FALSE,
        EXTENDED_STARTUPINFO_PRESENT | CREATE_UNICODE_ENVIRONMENT,
        NULL, NULL,
        &startupInfo.StartupInfo, &processInfo);

    if (!ok) {
        printf("[ERROR] CreateProcessW failed: %lu\n", GetLastError());
        return 1;
    }

    DWORD shellPid = processInfo.dwProcessId;
    printf("[2] Created cmd.exe via ConPTY, PID: %lu\n", shellPid);

    // Step 3: Create Job Object (exactly like process_manager.cpp)
    HANDLE hJob = CreateJobObjectA(NULL, NULL);
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION jobInfo = {0};
    jobInfo.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    SetInformationJobObject(hJob, JobObjectExtendedLimitInformation, &jobInfo, sizeof(jobInfo));

    // Check if already in a job
    HANDLE hProcess = OpenProcess(PROCESS_SET_QUOTA | PROCESS_TERMINATE | PROCESS_QUERY_INFORMATION, FALSE, shellPid);
    BOOL inJob = FALSE;
    IsProcessInJob(hProcess, NULL, &inJob);
    printf("[3] PID %lu already in a job: %s\n", shellPid, inJob ? "YES" : "NO");

    BOOL assigned = AssignProcessToJobObject(hJob, hProcess);
    printf("[4] AssignProcessToJobObject: %s (error: %lu)\n",
        assigned ? "OK" : "FAILED", assigned ? 0 : GetLastError());
    CloseHandle(hProcess);

    // Step 4: Wait a bit, then send a command via PTY input pipe
    Sleep(500);
    const char* command = "ping -n 300 127.0.0.1\r\n";
    DWORD written;
    WriteFile(inputWriteSide, command, (DWORD)strlen(command), &written, NULL);
    printf("[5] Sent command: ping -n 300 127.0.0.1\n");

    // Wait for children to spawn
    Sleep(2000);

    // Step 5: Show process tree
    printf("\n[6] Process tree:\n");
    printf("cmd.exe (PID: %lu)\n", shellPid);
    PrintProcessTree(shellPid);

    // Collect all descendant PIDs
    std::vector<DWORD> descendants;
    GetDescendants(shellPid, descendants);

    // Check job membership of children
    printf("\n[7] Job membership check:\n");
    for (DWORD pid : descendants) {
        HANDLE hp = OpenProcess(PROCESS_QUERY_INFORMATION, FALSE, pid);
        if (hp) {
            BOOL childInJob = FALSE;
            IsProcessInJob(hp, hJob, &childInJob);

            BOOL childInAnyJob = FALSE;
            IsProcessInJob(hp, NULL, &childInAnyJob);

            printf("  PID %lu: in our job=%s, in any job=%s\n",
                pid, childInJob ? "YES" : "NO", childInAnyJob ? "YES" : "NO");
            CloseHandle(hp);
        }
    }

    // Step 6: Kill using the selected method
    printf("\n[8] Killing processes...\n");

    if (useTreeKill) {
        // Proposed fix: walk the process tree
        KillProcessTree(shellPid);
    } else {
        // Current Marcha code: Job Object + _pty.kill()
        printf("  Calling TerminateJobObject...\n");
        BOOL terminated = TerminateJobObject(hJob, 1);
        printf("  TerminateJobObject returned: %s\n", terminated ? "TRUE" : "FALSE");

        // Then kill the process directly (like _pty?.kill() -> Process.killPid)
        HANDLE hKill = OpenProcess(PROCESS_TERMINATE, FALSE, shellPid);
        if (hKill) {
            TerminateProcess(hKill, 1);
            CloseHandle(hKill);
            printf("  TerminateProcess on shell PID: done\n");
        }
    }

    CloseHandle(hJob);

    // Close ConPTY
    ClosePseudoConsole(hPty);
    CloseHandle(inputReadSide);
    CloseHandle(inputWriteSide);
    CloseHandle(outputReadSide);
    CloseHandle(outputWriteSide);
    CloseHandle(processInfo.hThread);

    // Step 7: Wait and check for orphans
    Sleep(1000);
    printf("\n[9] Checking for orphans...\n");
    CheckOrphans(descendants);

    // Clean up any remaining orphans
    for (DWORD pid : descendants) {
        HANDLE h = OpenProcess(PROCESS_TERMINATE, FALSE, pid);
        if (h) {
            TerminateProcess(h, 1);
            CloseHandle(h);
        }
    }

    printf("\n=== Test complete ===\n");
    return 0;
}
