# test_kill_processes_v2.ps1
# More accurate simulation of Marcha's PTY flow + process tree kill fix

Add-Type @"
using System;
using System.Runtime.InteropServices;

public class JobObject2 {
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

    public const uint PROCESS_ALL_ACCESS = 0x001FFFFF;
    public const int JobObjectExtendedLimitInformation = 9;
    public const uint JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x2000;

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
        if (hJob == IntPtr.Zero) return IntPtr.Zero;

        var jobInfo = new JOBOBJECT_EXTENDED_LIMIT_INFORMATION();
        jobInfo.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;

        int size = Marshal.SizeOf(typeof(JOBOBJECT_EXTENDED_LIMIT_INFORMATION));
        IntPtr ptr = Marshal.AllocHGlobal(size);
        Marshal.StructureToPtr(jobInfo, ptr, false);

        bool set = SetInformationJobObject(hJob, JobObjectExtendedLimitInformation, ptr, (uint)size);
        Marshal.FreeHGlobal(ptr);

        if (!set) { CloseHandle(hJob); return IntPtr.Zero; }
        return hJob;
    }

    public static bool AssignToJob(IntPtr hJob, uint pid) {
        IntPtr hProcess = OpenProcess(PROCESS_ALL_ACCESS, false, pid);
        if (hProcess == IntPtr.Zero) {
            Console.WriteLine("  [ERROR] OpenProcess failed for PID " + pid + ": error " + Marshal.GetLastWin32Error());
            return false;
        }

        bool inJob = false;
        IsProcessInJob(hProcess, IntPtr.Zero, out inJob);
        Console.WriteLine("  PID " + pid + " already in a job: " + inJob);

        // Check if it's in OUR job specifically
        bool inOurJob = false;
        IsProcessInJob(hProcess, hJob, out inOurJob);
        Console.WriteLine("  PID " + pid + " in our job: " + inOurJob);

        bool assigned = AssignProcessToJobObject(hJob, hProcess);
        int err = Marshal.GetLastWin32Error();
        Console.WriteLine("  AssignProcessToJobObject: " + (assigned ? "OK" : "FAILED (error " + err + ")"));

        CloseHandle(hProcess);
        return assigned;
    }

    public static bool CheckInJob(IntPtr hJob, uint pid) {
        IntPtr hProcess = OpenProcess(PROCESS_ALL_ACCESS, false, pid);
        if (hProcess == IntPtr.Zero) return false;
        bool inJob = false;
        IsProcessInJob(hProcess, hJob, out inJob);
        CloseHandle(hProcess);
        return inJob;
    }
}
"@

function Get-AllDescendants {
    param([int]$RootPid)
    $result = @()
    $children = Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $RootPid -and $_.ProcessId -ne $RootPid }
    foreach ($child in $children) {
        $result += $child
        $result += Get-AllDescendants -RootPid $child.ProcessId
    }
    return $result
}

function Kill-ProcessTree {
    param([int]$RootPid)
    # Walk the tree bottom-up and kill each process
    $descendants = Get-AllDescendants -RootPid $RootPid
    # Kill children first (reverse order = deepest first)
    [array]::Reverse($descendants)
    foreach ($desc in $descendants) {
        try {
            Stop-Process -Id $desc.ProcessId -Force -ErrorAction Stop
            Write-Host "    Killed $($desc.Name) (PID: $($desc.ProcessId))" -ForegroundColor Green
        } catch {
            Write-Host "    Already dead: $($desc.Name) (PID: $($desc.ProcessId))" -ForegroundColor DarkGray
        }
    }
    # Kill the parent last
    try {
        Stop-Process -Id $RootPid -Force -ErrorAction Stop
        Write-Host "    Killed root process (PID: $RootPid)" -ForegroundColor Green
    } catch {
        Write-Host "    Root already dead (PID: $RootPid)" -ForegroundColor DarkGray
    }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " TEST A: Simulate Marcha's EXACT flow" -ForegroundColor Cyan
Write-Host " (start shell, assign job, THEN run command)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Start a bare cmd.exe shell (like Pty.start does)
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "cmd.exe"
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.CreateNoWindow = $true

$shell = [System.Diagnostics.Process]::Start($psi)
$shellPid = $shell.Id
Write-Host "[1] Started bare cmd.exe shell, PID: $shellPid"

# Step 2: Create job and assign (like Marcha does immediately after Pty.start)
Write-Host "[2] Creating and assigning Job Object..."
$hJob = [JobObject2]::CreateAndConfigureJob()
[JobObject2]::AssignToJob($hJob, [uint32]$shellPid)

Start-Sleep -Milliseconds 200

# Step 3: Send a command that spawns child processes (like Marcha sends command via PTY)
Write-Host "[3] Sending command to shell: 'ping -n 300 127.0.0.1'"
$shell.StandardInput.WriteLine("ping -n 300 127.0.0.1 > nul")
$shell.StandardInput.Flush()

Start-Sleep -Milliseconds 1000

# Step 4: Check process tree
Write-Host "[4] Process tree:"
Write-Host "    cmd.exe (PID: $shellPid)"
$descendants = Get-AllDescendants -RootPid $shellPid
foreach ($d in $descendants) {
    Write-Host "    |- $($d.Name) (PID: $($d.ProcessId))"
}

# Step 5: Check if children are in our job
Write-Host "[5] Checking job membership:"
Write-Host "    cmd.exe ($shellPid) in job: $([JobObject2]::CheckInJob($hJob, [uint32]$shellPid))"
foreach ($d in $descendants) {
    if ($d.Name -ne "conhost.exe") {
        $inJob = [JobObject2]::CheckInJob($hJob, [uint32]$d.ProcessId)
        Write-Host "    $($d.Name) ($($d.ProcessId)) in job: $inJob"
    }
}

# Step 6: Kill via Job Object (Marcha's method)
Write-Host ""
Write-Host "[6] Killing via TerminateJobObject..."
$result = [JobObject2]::TerminateJobObject($hJob, 1)
Write-Host "    TerminateJobObject returned: $result"
[JobObject2]::CloseHandle($hJob) | Out-Null

# Also kill the shell directly (like _pty?.kill())
try { $shell.Kill() } catch {}

Start-Sleep -Milliseconds 500

# Step 7: Check for orphans
Write-Host "[7] Checking for orphans..." -ForegroundColor Yellow
$orphanCount = 0
foreach ($d in $descendants) {
    try {
        Get-Process -Id $d.ProcessId -ErrorAction Stop | Out-Null
        Write-Host "    [ORPHAN!] $($d.Name) (PID: $($d.ProcessId))" -ForegroundColor Red
        Stop-Process -Id $d.ProcessId -Force -ErrorAction SilentlyContinue
        $orphanCount++
    } catch {
        Write-Host "    [DEAD] $($d.Name) (PID: $($d.ProcessId))" -ForegroundColor Green
    }
}

Write-Host ""
if ($orphanCount -gt 0) {
    Write-Host "RESULT: $orphanCount ORPHANS - Job Object method FAILS" -ForegroundColor Red
} else {
    Write-Host "RESULT: All killed - Job Object method WORKS" -ForegroundColor Green
}

Write-Host ""
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " TEST B: Process Tree Walk Kill (THE FIX)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Same setup
$psi2 = New-Object System.Diagnostics.ProcessStartInfo
$psi2.FileName = "cmd.exe"
$psi2.UseShellExecute = $false
$psi2.RedirectStandardInput = $true
$psi2.RedirectStandardOutput = $true
$psi2.RedirectStandardError = $true
$psi2.CreateNoWindow = $true

$shell2 = [System.Diagnostics.Process]::Start($psi2)
$shellPid2 = $shell2.Id
Write-Host "[1] Started cmd.exe, PID: $shellPid2"

Start-Sleep -Milliseconds 200

# Send command with deeper nesting: cmd -> cmd -> ping
$shell2.StandardInput.WriteLine('cmd.exe /c "cmd.exe /c ping -n 300 127.0.0.1 > nul"')
$shell2.StandardInput.Flush()

Start-Sleep -Milliseconds 1000

Write-Host "[2] Process tree before kill:"
Write-Host "    cmd.exe (PID: $shellPid2)"
$desc2 = Get-AllDescendants -RootPid $shellPid2
foreach ($d in $desc2) {
    Write-Host "    |- $($d.Name) (PID: $($d.ProcessId))"
}

Write-Host ""
Write-Host "[3] Killing via process tree walk (proposed fix)..."
Kill-ProcessTree -RootPid $shellPid2

Start-Sleep -Milliseconds 500

Write-Host ""
Write-Host "[4] Checking for orphans..." -ForegroundColor Yellow
$orphanCount2 = 0
# Re-fetch in case the tree changed
foreach ($d in $desc2) {
    try {
        Get-Process -Id $d.ProcessId -ErrorAction Stop | Out-Null
        Write-Host "    [ORPHAN!] $($d.Name) (PID: $($d.ProcessId))" -ForegroundColor Red
        Stop-Process -Id $d.ProcessId -Force -ErrorAction SilentlyContinue
        $orphanCount2++
    } catch {
        Write-Host "    [DEAD] $($d.Name) (PID: $($d.ProcessId))" -ForegroundColor Green
    }
}

Write-Host ""
if ($orphanCount2 -gt 0) {
    Write-Host "RESULT: $orphanCount2 ORPHANS still remain" -ForegroundColor Red
} else {
    Write-Host "RESULT: ALL KILLED - Process tree walk WORKS!" -ForegroundColor Green
}

Write-Host ""
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " CONCLUSION" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "The C++ code needs a kill_process_tree(DWORD pid) function that:" -ForegroundColor Yellow
Write-Host "  1. Uses CreateToolhelp32Snapshot to enumerate all processes" -ForegroundColor White
Write-Host "  2. Builds a tree of child processes from the root PID" -ForegroundColor White
Write-Host "  3. Terminates each process bottom-up (deepest children first)" -ForegroundColor White
Write-Host "  4. Falls back to this when Job Object termination fails" -ForegroundColor White
Write-Host ""
