/// Statistics for an individual process
class ChildProcessStats {
  final int pid;
  final String name;
  final double cpuUsage; // Percentage
  final int memoryUsage; // in KB

  const ChildProcessStats({
    required this.pid,
    required this.name,
    required this.cpuUsage,
    required this.memoryUsage,
  });

  String get memoryMB => '${(memoryUsage / 1024).toStringAsFixed(1)} MB';
  String get cpuPercent => '${cpuUsage.toStringAsFixed(1)}%';
}

/// Statistics for a process and its child processes
class ProcessStats {
  final int pid;
  final double cpuUsage; // Percentage (aggregated)
  final int memoryUsage; // in KB (aggregated)
  final DateTime timestamp;
  final int processCount; // Number of processes in tree (parent + children)
  final List<ChildProcessStats> children; // Individual child process stats

  const ProcessStats({
    required this.pid,
    required this.cpuUsage,
    required this.memoryUsage,
    required this.timestamp,
    this.processCount = 1,
    this.children = const [],
  });

  String get memoryMB => '${(memoryUsage / 1024).toStringAsFixed(1)} MB';
  String get cpuPercent => '${cpuUsage.toStringAsFixed(1)}%';

  ProcessStats copyWith({
    int? pid,
    double? cpuUsage,
    int? memoryUsage,
    DateTime? timestamp,
    int? processCount,
    List<ChildProcessStats>? children,
  }) {
    return ProcessStats(
      pid: pid ?? this.pid,
      cpuUsage: cpuUsage ?? this.cpuUsage,
      memoryUsage: memoryUsage ?? this.memoryUsage,
      timestamp: timestamp ?? this.timestamp,
      processCount: processCount ?? this.processCount,
      children: children ?? this.children,
    );
  }
}

/// Icon mapping for common processes
class ProcessIcons {
  static const Map<String, String> _iconMap = {
    // Shells
    'cmd': 'terminal',
    'cmd.exe': 'terminal',
    'powershell': 'terminal_ps',
    'powershell.exe': 'terminal_ps',
    'pwsh': 'terminal_ps',
    'pwsh.exe': 'terminal_ps',
    'bash': 'terminal',
    'bash.exe': 'terminal',
    'wsl': 'terminal',
    'wsl.exe': 'terminal',

    // Languages
    'python': 'python',
    'python.exe': 'python',
    'python3': 'python',
    'python3.exe': 'python',
    'pythonw': 'python',
    'pythonw.exe': 'python',
    'node': 'node',
    'node.exe': 'node',
    'java': 'java',
    'java.exe': 'java',
    'javaw': 'java',
    'javaw.exe': 'java',
    'ruby': 'ruby',
    'ruby.exe': 'ruby',
    'go': 'go',
    'go.exe': 'go',
    'rust': 'rust',
    'rustc': 'rust',
    'cargo': 'rust',
    'dotnet': 'dotnet',
    'dotnet.exe': 'dotnet',

    // Build tools
    'npm': 'npm',
    'npm.cmd': 'npm',
    'npx': 'npm',
    'npx.cmd': 'npm',
    'yarn': 'yarn',
    'yarn.cmd': 'yarn',
    'pnpm': 'pnpm',
    'pnpm.cmd': 'pnpm',
    'gradle': 'gradle',
    'gradlew': 'gradle',
    'maven': 'maven',
    'mvn': 'maven',
    'pip': 'python',
    'pip.exe': 'python',
    'pip3': 'python',

    // Editors/Dev tools
    'code': 'vscode',
    'code.exe': 'vscode',
    'git': 'git',
    'git.exe': 'git',
    'docker': 'docker',
    'docker.exe': 'docker',
    'flutter': 'flutter',
    'flutter.bat': 'flutter',
    'dart': 'dart',
    'dart.exe': 'dart',

    // System
    'conhost': 'system',
    'conhost.exe': 'system',
    'explorer': 'folder',
    'explorer.exe': 'folder',
  };

  static String getIconType(String processName) {
    final name = processName.toLowerCase();
    return _iconMap[name] ?? 'process';
  }
}
