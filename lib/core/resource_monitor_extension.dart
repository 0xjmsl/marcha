import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/process_stats.dart';
import '../models/task.dart';
import 'core.dart';

/// Centralized resource monitoring for all running tasks
///
/// Instead of each task running its own PowerShell queries,
/// this extension runs ONE query every 5 seconds and distributes
/// the results to all running tasks.
class ResourceMonitorExtension {
  final Core _core;

  ResourceMonitorExtension(this._core);

  Timer? _monitoringTimer;

  // CPU percentage calculation state (track previous sample for delta)
  final Map<int, double> _lastCpuTimes = {}; // PID -> cumulative CPU seconds
  DateTime? _lastCpuSampleTime;

  bool get isMonitoring => _monitoringTimer != null;

  /// Start monitoring if there are running tasks
  void _ensureMonitoring() {
    final runningTasks = _core.tasks.running;

    if (runningTasks.isEmpty) {
      _stopMonitoring();
      return;
    }

    if (_monitoringTimer != null) return; // Already running

    // Collect stats every 5 seconds
    _monitoringTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _collectAndDistributeStats();
    });

    // Collect initial stats immediately
    _collectAndDistributeStats();
  }

  /// Stop monitoring when no tasks are running
  void _stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _lastCpuTimes.clear();
    _lastCpuSampleTime = null;
  }

  /// Called when a task starts - ensures monitoring is active
  void onTaskStarted(Task task) {
    _ensureMonitoring();
  }

  /// Called when a task stops - may stop monitoring if no tasks left
  void onTaskStopped(Task task) {
    // Clean up CPU time tracking for this task's processes
    // (will be cleaned up naturally on next collection)
    _ensureMonitoring();
  }

  /// Collect stats for all running tasks in ONE query
  Future<void> _collectAndDistributeStats() async {
    final runningTasks = _core.tasks.running;
    if (runningTasks.isEmpty) {
      _stopMonitoring();
      return;
    }

    // Gather all root PIDs
    final tasksByPid = <int, Task>{};
    for (final task in runningTasks) {
      if (task.pid != null) {
        tasksByPid[task.pid!] = task;
      }
    }

    if (tasksByPid.isEmpty) return;

    try {
      // Step 1: Get ALL processes ONCE to build process trees
      final processTree = await _getProcessTree();
      if (processTree == null) return;

      // Step 2: For each task, find its process tree
      final allPidsToQuery = <int>{};
      final taskTreePids = <int, List<int>>{}; // rootPid -> list of all PIDs in tree

      for (final rootPid in tasksByPid.keys) {
        final treePids = _buildProcessTree(rootPid, processTree);
        if (treePids.isNotEmpty) {
          taskTreePids[rootPid] = treePids;
          allPidsToQuery.addAll(treePids);
        }
      }

      if (allPidsToQuery.isEmpty) return;

      // Step 3: Get stats for ALL PIDs in ONE query
      final allStats = await _getProcessStats(allPidsToQuery.toList());
      if (allStats == null) return;

      // Step 4: Distribute stats to each task
      final now = DateTime.now();
      final elapsedSeconds = _lastCpuSampleTime != null
          ? now.difference(_lastCpuSampleTime!).inMilliseconds / 1000.0
          : 0.0;

      final Map<int, double> currentCpuTimes = {};

      for (final entry in tasksByPid.entries) {
        final rootPid = entry.key;
        final task = entry.value;
        final treePids = taskTreePids[rootPid] ?? [];

        if (treePids.isEmpty) continue;

        // Aggregate stats for this task's process tree
        double totalCpuPercent = 0.0;
        int totalMemory = 0;
        int foundCount = 0;
        final List<ChildProcessStats> children = [];

        for (final pid in treePids) {
          final procStats = allStats[pid];
          if (procStats == null) continue;

          final cpuTimeSeconds = ((procStats['CPU'] as num?) ?? 0.0).toDouble();
          final memory = (procStats['Memory'] as int?) ?? 0;
          final procName = (procStats['Name'] as String?) ?? 'Unknown';

          // Calculate actual CPU percentage from delta
          double cpuPercent = 0.0;
          if (elapsedSeconds > 0) {
            final lastCpuTime = _lastCpuTimes[pid] ?? cpuTimeSeconds;
            final deltaCpuTime = cpuTimeSeconds - lastCpuTime;
            cpuPercent = (deltaCpuTime / elapsedSeconds) * 100.0;
            if (cpuPercent < 0) cpuPercent = 0.0;
          }
          currentCpuTimes[pid] = cpuTimeSeconds;

          totalCpuPercent += cpuPercent;
          totalMemory += memory;
          foundCount++;

          children.add(ChildProcessStats(
            pid: pid,
            name: procName,
            cpuUsage: cpuPercent,
            memoryUsage: memory,
          ));
        }

        if (foundCount == 0) continue;

        // Sort children: root process first, then by memory usage descending
        children.sort((a, b) {
          if (a.pid == rootPid) return -1;
          if (b.pid == rootPid) return 1;
          return b.memoryUsage.compareTo(a.memoryUsage);
        });

        final stats = ProcessStats(
          pid: rootPid,
          cpuUsage: totalCpuPercent,
          memoryUsage: totalMemory,
          timestamp: now,
          processCount: foundCount,
          children: children,
        );

        // Send stats to the task
        task.updateStats(stats);
      }

      // Update tracking state for next delta calculation
      _lastCpuTimes.clear();
      _lastCpuTimes.addAll(currentCpuTimes);
      _lastCpuSampleTime = now;

      // Notify UI to update
      _core.notify();
    } catch (e) {
      // Silently handle errors - monitoring should not crash the app
    }
  }

  /// Get all processes with their parent relationships - ONE query
  Future<Map<int, int>?> _getProcessTree() async {
    try {
      final result = await Process.run('powershell', [
        '-Command',
        'Get-CimInstance Win32_Process | Select-Object ProcessId,ParentProcessId | ConvertTo-Json'
      ]);

      if (result.exitCode != 0 || result.stdout.toString().isEmpty) {
        return null;
      }

      final dynamic jsonData = jsonDecode(result.stdout.toString());
      final List<dynamic> processes = jsonData is List ? jsonData : [jsonData];

      // Build PID -> ParentPID map
      final Map<int, int> parentMap = {};
      for (final proc in processes) {
        final procId = proc['ProcessId'] as int?;
        final parentId = proc['ParentProcessId'] as int?;
        if (procId != null && parentId != null) {
          parentMap[procId] = parentId;
        }
      }

      return parentMap;
    } catch (e) {
      return null;
    }
  }

  /// Build list of all PIDs in a process tree starting from root
  List<int> _buildProcessTree(int rootPid, Map<int, int> parentMap) {
    // Check if root exists
    if (!parentMap.containsKey(rootPid)) {
      return [];
    }

    // Build children map from parent map
    final childrenMap = <int, List<int>>{};
    for (final entry in parentMap.entries) {
      childrenMap.putIfAbsent(entry.value, () => []).add(entry.key);
    }

    // BFS to collect all descendants
    final treePids = <int>{rootPid};
    final queue = <int>[rootPid];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final children = childrenMap[current] ?? [];
      for (final child in children) {
        if (!treePids.contains(child)) {
          treePids.add(child);
          queue.add(child);
        }
      }
    }

    return treePids.toList();
  }

  /// Get stats for a list of PIDs - ONE query
  Future<Map<int, Map<String, dynamic>>?> _getProcessStats(List<int> pids) async {
    if (pids.isEmpty) return null;

    try {
      final pidsString = pids.join(',');
      final result = await Process.run('powershell', [
        '-Command',
        'Get-Process -Id $pidsString -ErrorAction SilentlyContinue | Select-Object Id,ProcessName,CPU,WorkingSet | ConvertTo-Json'
      ]);

      if (result.exitCode != 0 || result.stdout.toString().isEmpty) {
        return null;
      }

      final dynamic jsonData = jsonDecode(result.stdout.toString());
      final List<dynamic> processes = jsonData is List ? jsonData : [jsonData];

      final Map<int, Map<String, dynamic>> statsMap = {};
      for (final proc in processes) {
        final procId = proc['Id'] as int?;
        if (procId != null) {
          statsMap[procId] = {
            'Name': proc['ProcessName'] as String? ?? 'Unknown',
            'CPU': proc['CPU'] != null ? (proc['CPU'] as num).toDouble() : 0.0,
            'Memory': proc['WorkingSet'] != null
                ? ((proc['WorkingSet'] as num) / 1024).round()
                : 0,
          };
        }
      }

      return statsMap;
    } catch (e) {
      return null;
    }
  }
}
