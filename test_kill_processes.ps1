# test_kill_processes.ps1
# Diagnostic script to test whether Windows Job Objects properly kill process trees
# Simulates what Marcha does: spawn cmd.exe -> child processes -> kill via Job Object

Add-Type @"
using System;
using System.Runtime.InteropServices;

public class JobObject {
    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern IntPtr CreateJobObject(IntPtr lpJobAttributes, string lpName);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetInformationJobObject(IntPtr hJob, int JobObjectInfoClass, IntPtr lpJobObjectInfo, uint cbJobObjectInfoLength);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandles, uint dwProcessId);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool AssignProcessToJobObject(IntPtr hJob, IntPtr hProcess);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool TerminateJobObject(IntPtr hJob, uint uExitCode);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CloseHandle(IntPtr hObject);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool IsProcessInJob(IntPtr ProcessHandle, IntPtr JobHandle, out bool Result);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool QueryInformationJobObject(IntPtr hJob, int JobObjectInformationClass, IntPtr lpJobObjectInformation, uint cbJobObjectInformationLength, out uint lpReturnLength);

    // Constants
    public const uint PROCESS_SET_QUOTA = 0x0100;
    public const uint PROCESS_TERMINATE = 0x0001;
    public const uint PROCESS_QUERY_INFORMATION = 0x0400;
    public const int JobObjectExtendedLimitInformation = 9;
    public const int JobObjectBasicProcessIdList = 3;
    public const uint JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x2000;

    // Struct for JOBOBJECT_EXTENDED_LIMIT_INFORMATION (simplified - only need LimitFlags)
    [StructLayout(LayoutKind.Sequential)]
    public struct JOBOBJECT_BASIC_LIMIT_INFORMATION {
        public long PerProcessUserTimeLimit;
        public long PerJobUserTimeLimit;
        public uint LimitFlags;
        public UIntPtr MinimumWorkingSetSize;
        public UIntPtr MaximumWorkingSetSize;
        public uint ActiveProcessLimit;
        public UIntPtr Affinity;
        public uint PriorityClass;
        public uint SchedulingClass;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct IO_COUNTERS {
        public ulong ReadOperationCount;
        public ulong WriteOperationCount;
        public ulong OtherOperationCount;
        public ulong ReadTransferCount;
        public ulong WriteTransferCount;
        public ulong OtherTransferCount;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct JOBOBJECT_EXTENDED_LIMIT_INFORMATION {
        public JOBOBJECT_BASIC_LIMIT_INFORMATION BasicLimitInformation;
        public IO_COUNTERS IoInfo;
        public UIntPtr ProcessMemoryLimit;
        public UIntPtr JobMemoryLimit;
        public UIntPtr PeakProcessMemoryUsed;
        public UIntPtr PeakJobMemoryUsed;
    }

    public static IntPtr CreateAndConfigureJob() {
        IntPtr hJob = CreateJobObject(IntPtr.Zero, null);
        if (hJob == IntPtr.Zero) {
            Console.WriteLine("[ERROR] CreateJobObject failed: " + Marshal.GetLastWin32Error());
            return IntPtr.Zero;
        }

        var jobInfo = new JOBOBJECT_EXTENDED_LIMIT_INFORMATION();
        jobInfo.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;

        int size = Marshal.SizeOf(typeof(JOBOBJECT_EXTENDED_LIMIT_INFORMATION));
        IntPtr ptr = Marshal.AllocHGlobal(size);
        Marshal.StructureToPtr(jobInfo, ptr, false);

        bool set = SetInformationJobObject(hJob, JobObjectExtendedLimitInformation, ptr, (uint)size);
        Marshal.FreeHGlobal(ptr);

        if (!set) {
            Console.WriteLine("[ERROR] SetInformationJobObject failed: " + Marshal.GetLastWin32Error());
            CloseHandle(hJob);
            return IntPtr.Zero;
        }

        return hJob;
    }

    public static bool AssignToJob(IntPtr hJob, uint pid) {
        IntPtr hProcess = OpenProcess(PROCESS_SET_QUOTA | PROCESS_TERMINATE | PROCESS_QUERY_INFORMATION, false, pid);
        if (hProcess == IntPtr.Zero) {
            Console.WriteLine("[ERROR] OpenProcess failed for PID " + pid + ": " + Marshal.GetLastWin32Error());
            return false;
        }

        // Check if already in a job
        bool inJob = false;
        IsProcessInJob(hProcess, IntPtr.Zero, out inJob);
        Console.WriteLine("[INFO] PID " + pid + " already in a job: " + inJob);

        bool assigned = AssignProcessToJobObject(hJob, hProcess);
        if (!assigned) {
            int err = Marshal.GetLastWin32Error();
            Console.WriteLine("[ERROR] AssignProcessToJobObject FAILED for PID " + pid + ": Win32 error " + err);
            Console.WriteLine("[!!!] THIS IS THE BUG - Process could not be assigned to job.");
            Console.WriteLine("[!!!] TerminateJobObject will NOT kill this process or its children.");
        } else {
            Console.WriteLine("[OK] AssignProcessToJobObject succeeded for PID " + pid);
        }

        CloseHandle(hProcess);
        return assigned;
    }
}
"@

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Marcha Process Kill Diagnostic" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# --- TEST 1: Simulate exactly what Marcha does ---
Write-Host "--- TEST 1: Simulate Marcha's kill flow ---" -ForegroundColor Yellow
Write-Host ""

# Spawn cmd.exe that starts a child process (like what Marcha does with PTY)
Write-Host "[1] Spawning cmd.exe with a long-running child process (ping)..."
$proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c ping -n 300 127.0.0.1 > nul" -PassThru -WindowStyle Hidden

Start-Sleep -Milliseconds 500

$parentPid = $proc.Id
Write-Host "[2] Parent cmd.exe PID: $parentPid"

# Find child processes
$children = Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $parentPid }
Write-Host "[3] Child processes of PID $parentPid`:"
foreach ($child in $children) {
    Write-Host "    - $($child.Name) (PID: $($child.ProcessId))"
}

# Now do what Marcha does: create job, assign, terminate
Write-Host ""
Write-Host "[4] Creating Job Object (same as Marcha's create_job_for_process)..."
$hJob = [JobObject]::CreateAndConfigureJob()

if ($hJob -ne [IntPtr]::Zero) {
    Write-Host "[5] Assigning parent process to job..."
    $assigned = [JobObject]::AssignToJob($hJob, [uint32]$parentPid)

    Write-Host ""
    Write-Host "[6] Calling TerminateJobObject (same as Marcha's terminate_job)..."
    $terminated = [JobObject]::TerminateJobObject($hJob, 1)
    Write-Host "    TerminateJobObject returned: $terminated"

    [JobObject]::CloseHandle($hJob) | Out-Null
} else {
    Write-Host "[ERROR] Could not create job object!"
}

# Also kill the PTY (same as _pty?.kill())
Write-Host "[7] Killing parent process directly (same as _pty?.kill())..."
try {
    Stop-Process -Id $parentPid -Force -ErrorAction Stop
    Write-Host "    Parent killed."
} catch {
    Write-Host "    Parent already dead (job may have killed it)."
}

Start-Sleep -Milliseconds 500

# Check if children survived
Write-Host ""
Write-Host "[8] Checking for orphaned children..." -ForegroundColor Yellow
$orphans = @()
foreach ($child in $children) {
    try {
        $p = Get-Process -Id $child.ProcessId -ErrorAction Stop
        $orphans += $child
        Write-Host "    [ORPHAN!] $($child.Name) (PID: $($child.ProcessId)) is STILL RUNNING!" -ForegroundColor Red
    } catch {
        Write-Host "    [OK] $($child.Name) (PID: $($child.ProcessId)) was terminated." -ForegroundColor Green
    }
}

# Clean up any orphans
foreach ($orphan in $orphans) {
    Stop-Process -Id $orphan.ProcessId -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " TEST 1 RESULT" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
if ($orphans.Count -gt 0) {
    Write-Host " ORPHANS DETECTED - Job Object failed to kill children" -ForegroundColor Red
} else {
    Write-Host " All children killed successfully" -ForegroundColor Green
}

# --- TEST 2: Check if current PowerShell is in a job (explains why assignment fails) ---
Write-Host ""
Write-Host ""
Write-Host "--- TEST 2: Is THIS process already in a job? ---" -ForegroundColor Yellow
$selfPid = $PID
$hSelf = [JobObject]::OpenProcess(0x0400, $false, [uint32]$selfPid)
if ($hSelf -ne [IntPtr]::Zero) {
    $inJob = $false
    [JobObject]::IsProcessInJob($hSelf, [IntPtr]::Zero, [ref]$inJob)
    Write-Host "PowerShell PID $selfPid is in a job: $inJob"
    if ($inJob) {
        Write-Host "[!!!] This means child processes spawned from here are ALSO in a job." -ForegroundColor Red
        Write-Host "[!!!] AssignProcessToJobObject may fail if the existing job doesn't allow nesting." -ForegroundColor Red
    }
    [JobObject]::CloseHandle($hSelf) | Out-Null
}

# --- TEST 3: Deep tree test (cmd -> cmd -> ping) ---
Write-Host ""
Write-Host ""
Write-Host "--- TEST 3: Deep process tree (grandchild processes) ---" -ForegroundColor Yellow

# cmd.exe spawns another cmd.exe which spawns ping
$proc2 = Start-Process -FilePath "cmd.exe" -ArgumentList '/c "cmd.exe /c ping -n 300 127.0.0.1 > nul"' -PassThru -WindowStyle Hidden
Start-Sleep -Milliseconds 1000

$parent2Pid = $proc2.Id
Write-Host "[1] Top-level cmd.exe PID: $parent2Pid"

# Build full process tree
function Get-ProcessTree {
    param([int]$ParentPid, [int]$Depth = 0)
    $children = Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $ParentPid -and $_.ProcessId -ne $ParentPid }
    $result = @()
    foreach ($child in $children) {
        $indent = "  " * $Depth
        Write-Host "    ${indent}|- $($child.Name) (PID: $($child.ProcessId))"
        $result += $child
        $result += Get-ProcessTree -ParentPid $child.ProcessId -Depth ($Depth + 1)
    }
    return $result
}

Write-Host "[2] Process tree:"
Write-Host "    cmd.exe (PID: $parent2Pid)"
$allDescendants = Get-ProcessTree -ParentPid $parent2Pid

Write-Host ""
Write-Host "[3] Creating Job and assigning top-level process..."
$hJob2 = [JobObject]::CreateAndConfigureJob()
if ($hJob2 -ne [IntPtr]::Zero) {
    $assigned2 = [JobObject]::AssignToJob($hJob2, [uint32]$parent2Pid)

    Write-Host "[4] Terminating via Job Object..."
    [JobObject]::TerminateJobObject($hJob2, 1) | Out-Null
    [JobObject]::CloseHandle($hJob2) | Out-Null
}

# Kill parent directly too
try { Stop-Process -Id $parent2Pid -Force -ErrorAction Stop } catch {}

Start-Sleep -Milliseconds 500

Write-Host "[5] Checking for orphaned descendants..." -ForegroundColor Yellow
$orphanCount = 0
foreach ($desc in $allDescendants) {
    try {
        Get-Process -Id $desc.ProcessId -ErrorAction Stop | Out-Null
        Write-Host "    [ORPHAN!] $($desc.Name) (PID: $($desc.ProcessId)) STILL RUNNING" -ForegroundColor Red
        Stop-Process -Id $desc.ProcessId -Force -ErrorAction SilentlyContinue
        $orphanCount++
    } catch {
        Write-Host "    [OK] $($desc.Name) (PID: $($desc.ProcessId)) terminated" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " FINAL DIAGNOSIS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "If AssignProcessToJobObject failed above, the root cause is:" -ForegroundColor Yellow
Write-Host "  The PTY process (cmd.exe) is already in a Windows Job Object." -ForegroundColor Yellow
Write-Host "  Marcha's create_job_for_process() silently continues even when" -ForegroundColor Yellow
Write-Host "  assignment fails (process_manager.cpp lines 341-345)." -ForegroundColor Yellow
Write-Host "  This means TerminateJobObject operates on an EMPTY job," -ForegroundColor Yellow
Write-Host "  and only _pty.kill() fires - which only kills cmd.exe, not children." -ForegroundColor Yellow
Write-Host ""
Write-Host "FIX OPTIONS:" -ForegroundColor Green
Write-Host "  1. Use CREATE_BREAKAWAY_FROM_JOB flag when spawning the PTY process" -ForegroundColor Green
Write-Host "  2. Enumerate the process tree by PID and kill each process individually" -ForegroundColor Green
Write-Host "  3. Use both: try Job Object, fallback to tree walk" -ForegroundColor Green
Write-Host ""
