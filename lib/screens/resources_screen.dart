import 'dart:async';
import 'package:flutter/material.dart';
import '../core/core.dart';
import '../models/task.dart';
import '../models/process_stats.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Full-screen resources view (used in sidebar navigation)
class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);
    final styles = AppTheme.of(context);

    return Container(
      color: colors.background,
      child: Column(
        children: [
          _buildHeader(colors, styles.scale),
          const Expanded(
            child: ResourcesContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppColorScheme colors, double scale) {
    return Container(
      height: 36 * scale,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.border),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.monitor_heart, color: colors.textMuted, size: 16),
          const SizedBox(width: 8),
          Text('Resources',
              style: AppTheme.bodyNormal.copyWith(color: colors.textPrimary)),
          const Spacer(),
        ],
      ),
    );
  }
}

/// Reusable resources content widget (used by both ResourcesScreen and ResourcesPane)
class ResourcesContent extends StatefulWidget {
  const ResourcesContent({super.key});

  @override
  State<ResourcesContent> createState() => _ResourcesContentState();
}

class _ResourcesContentState extends State<ResourcesContent> {
  Timer? _refreshTimer;

  // Sorting state
  String _sortColumn = 'name';
  bool _sortAscending = true;

  // Expanded tasks (task IDs)
  final Set<String> _expandedTasks = {};

  @override
  void initState() {
    super.initState();
    // Refresh UI every 2 seconds to update duration and stats
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _toggleExpanded(String taskId) {
    setState(() {
      if (_expandedTasks.contains(taskId)) {
        _expandedTasks.remove(taskId);
      } else {
        _expandedTasks.add(taskId);
      }
    });
  }

  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
  }

  List<Task> _getSortedTasks(List<Task> tasks) {
    final sorted = List<Task>.from(tasks);
    sorted.sort((a, b) {
      int compare;
      switch (_sortColumn) {
        case 'name':
          compare = a.name.compareTo(b.name);
        case 'pid':
          compare = (a.pid ?? 0).compareTo(b.pid ?? 0);
        case 'children':
          compare = (a.latestStats?.processCount ?? 0)
              .compareTo(b.latestStats?.processCount ?? 0);
        case 'cpu':
          compare = (a.latestStats?.cpuUsage ?? 0)
              .compareTo(b.latestStats?.cpuUsage ?? 0);
        case 'memory':
          compare = (a.latestStats?.memoryUsage ?? 0)
              .compareTo(b.latestStats?.memoryUsage ?? 0);
        case 'duration':
          compare = a.createdAt.compareTo(b.createdAt);
        default:
          compare = 0;
      }
      return _sortAscending ? compare : -compare;
    });
    return sorted;
  }

  Future<void> _confirmKill(Task task) async {
    final colors = AppColorsExtension.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Kill Task', style: TextStyle(color: colors.textPrimary)),
        content: Text(
          'Are you sure you want to kill "${task.name}"?\nThis will terminate the process and all child processes.',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: colors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Kill'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      core.tasks.kill(task.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);

    return ListenableBuilder(
      listenable: core,
      builder: (context, _) {
        final runningTasks = core.tasks.running;

        if (runningTasks.isEmpty) {
          return _buildEmptyState(colors);
        }

        return Column(
          children: [
            _buildSummaryCards(colors, runningTasks),
            Expanded(
              child: _buildProcessTable(colors, runningTasks),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(AppColorScheme colors) {
    final scale = core.settings.resourcesTextScale;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.hourglass_empty,
            size: 64 * scale,
            color: colors.textMuted,
          ),
          SizedBox(height: 16 * scale),
          Text(
            'No Running Tasks',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 18 * scale,
            ),
          ),
          SizedBox(height: 8 * scale),
          Text(
            'Launch a task to see resource monitoring',
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 14 * scale,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(AppColorScheme colors, List<Task> tasks) {
    final scale = core.settings.resourcesTextScale;
    // Aggregate stats
    int totalProcesses = 0;
    double totalCpu = 0;
    int totalMemory = 0;

    for (final task in tasks) {
      final stats = task.latestStats;
      if (stats != null) {
        totalProcesses += stats.processCount;
        totalCpu += stats.cpuUsage;
        totalMemory += stats.memoryUsage;
      }
    }

    return Container(
      padding: EdgeInsets.all(12 * scale),
      decoration: BoxDecoration(
        color: colors.surfaceLight,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          _SummaryCard(
            icon: Icons.play_circle,
            label: 'Running',
            value: '${tasks.length}',
            color: AppColors.success,
            colors: colors,
            scale: scale,
          ),
          SizedBox(width: 12 * scale),
          _SummaryCard(
            icon: Icons.memory,
            label: 'CPU',
            value: '${totalCpu.toStringAsFixed(1)}%',
            color: AppColors.info,
            colors: colors,
            scale: scale,
          ),
          SizedBox(width: 12 * scale),
          _SummaryCard(
            icon: Icons.storage,
            label: 'Memory',
            value: '${(totalMemory / 1024).toStringAsFixed(1)} MB',
            color: AppColors.warning,
            colors: colors,
            scale: scale,
          ),
          SizedBox(width: 12 * scale),
          _SummaryCard(
            icon: Icons.account_tree,
            label: 'Processes',
            value: '$totalProcesses',
            color: colors.textSecondary,
            colors: colors,
            scale: scale,
          ),
        ],
      ),
    );
  }

  Widget _buildProcessTable(AppColorScheme colors, List<Task> tasks) {
    final sortedTasks = _getSortedTasks(tasks);

    return SingleChildScrollView(
      child: Column(
        children: [
          // Table header
          _buildTableHeader(colors),
          // Table rows with expandable children
          ...sortedTasks.expand((task) => [
                _buildTableRow(colors, task),
                if (_expandedTasks.contains(task.id))
                  _buildChildrenSection(colors, task),
              ]),
        ],
      ),
    );
  }

  Widget _buildTableHeader(AppColorScheme colors) {
    final scale = core.settings.resourcesTextScale;
    return Container(
      height: 32 * scale,
      padding: EdgeInsets.symmetric(horizontal: 12 * scale),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          SizedBox(width: 24 * scale), // Expand button space
          _SortableHeader(
            label: 'Task',
            column: 'name',
            width: 176 * scale,
            currentSort: _sortColumn,
            ascending: _sortAscending,
            onSort: _onSort,
            colors: colors,
            scale: scale,
          ),
          _SortableHeader(
            label: 'PID',
            column: 'pid',
            width: 80 * scale,
            currentSort: _sortColumn,
            ascending: _sortAscending,
            onSort: _onSort,
            colors: colors,
            scale: scale,
          ),
          _SortableHeader(
            label: 'Children',
            column: 'children',
            width: 80 * scale,
            currentSort: _sortColumn,
            ascending: _sortAscending,
            onSort: _onSort,
            colors: colors,
            scale: scale,
          ),
          _SortableHeader(
            label: 'CPU',
            column: 'cpu',
            width: 120 * scale,
            currentSort: _sortColumn,
            ascending: _sortAscending,
            onSort: _onSort,
            colors: colors,
            scale: scale,
          ),
          _SortableHeader(
            label: 'Memory',
            column: 'memory',
            width: 140 * scale,
            currentSort: _sortColumn,
            ascending: _sortAscending,
            onSort: _onSort,
            colors: colors,
            scale: scale,
          ),
          _SortableHeader(
            label: 'Duration',
            column: 'duration',
            width: 100 * scale,
            currentSort: _sortColumn,
            ascending: _sortAscending,
            onSort: _onSort,
            colors: colors,
            scale: scale,
          ),
          const Spacer(),
          SizedBox(
            width: 60 * scale,
            child: Text(
              'Actions',
              style: AppTheme.monoSmall.copyWith(
                color: colors.textMuted,
                fontWeight: FontWeight.bold,
                fontSize: 12 * scale,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(AppColorScheme colors, Task task) {
    final scale = core.settings.resourcesTextScale;
    // Get emoji from template if available
    String emoji = '';
    if (task.templateId != null) {
      final template = core.templates.getById(task.templateId!);
      emoji = template?.emoji ?? '';
    }

    final stats = task.latestStats;
    final duration = DateTime.now().difference(task.createdAt);
    final isExpanded = _expandedTasks.contains(task.id);
    final hasChildren = (stats?.children.length ?? 0) > 1;

    return Container(
      height: 40 * scale,
      padding: EdgeInsets.symmetric(horizontal: 12 * scale),
      decoration: BoxDecoration(
        color: isExpanded ? colors.surfaceLight : null,
        border: Border(
            bottom: BorderSide(
                color: colors.border.withValues(alpha: isExpanded ? 1 : 0.5))),
      ),
      child: Row(
        children: [
          // Expand button
          SizedBox(
            width: 24 * scale,
            child: hasChildren
                ? IconButton(
                    icon: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      size: 18 * scale,
                    ),
                    color: colors.textMuted,
                    tooltip: isExpanded ? 'Collapse' : 'Expand to see children',
                    onPressed: () => _toggleExpanded(task.id),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                : null,
          ),
          // Task name with emoji
          SizedBox(
            width: 176 * scale,
            child: Row(
              children: [
                if (emoji.isNotEmpty) ...[
                  Text(emoji, style: TextStyle(fontSize: 16 * scale)),
                  SizedBox(width: 8 * scale),
                ],
                Container(
                  width: 8 * scale,
                  height: 8 * scale,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8 * scale),
                Expanded(
                  child: Text(
                    task.name,
                    style: TextStyle(color: colors.textPrimary, fontSize: 14 * scale),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // PID
          SizedBox(
            width: 80 * scale,
            child: Text(
              task.pid?.toString() ?? '-',
              style: AppTheme.monoSmall.copyWith(color: colors.textSecondary, fontSize: 12 * scale),
            ),
          ),
          // Children count
          SizedBox(
            width: 80 * scale,
            child: Text(
              stats != null ? '${stats.processCount}' : '-',
              style: AppTheme.monoSmall.copyWith(color: colors.textSecondary, fontSize: 12 * scale),
            ),
          ),
          // CPU with sparkline
          SizedBox(
            width: 120 * scale,
            child: Row(
              children: [
                SizedBox(
                  width: 40 * scale,
                  height: 20 * scale,
                  child: _Sparkline(
                    data: task.statsHistory.map((s) => s.cpuUsage).toList(),
                    color: AppColors.info,
                  ),
                ),
                SizedBox(width: 4 * scale),
                Text(
                  stats?.cpuPercent ?? '-',
                  style: AppTheme.monoSmall.copyWith(color: AppColors.info, fontSize: 12 * scale),
                ),
              ],
            ),
          ),
          // Memory with sparkline
          SizedBox(
            width: 140 * scale,
            child: Row(
              children: [
                SizedBox(
                  width: 40 * scale,
                  height: 20 * scale,
                  child: _Sparkline(
                    data: task.statsHistory
                        .map((s) => s.memoryUsage.toDouble())
                        .toList(),
                    color: AppColors.warning,
                  ),
                ),
                SizedBox(width: 4 * scale),
                Text(
                  stats?.memoryMB ?? '-',
                  style: AppTheme.monoSmall.copyWith(color: AppColors.warning, fontSize: 12 * scale),
                ),
              ],
            ),
          ),
          // Duration
          SizedBox(
            width: 100 * scale,
            child: Text(
              _formatDuration(duration),
              style: AppTheme.monoSmall.copyWith(color: colors.textMuted, fontSize: 12 * scale),
            ),
          ),
          const Spacer(),
          // Kill button
          SizedBox(
            width: 60 * scale,
            child: IconButton(
              icon: Icon(Icons.stop_circle, size: 20 * scale),
              color: AppColors.error,
              tooltip: 'Kill task',
              onPressed: () => _confirmKill(task),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildrenSection(AppColorScheme colors, Task task) {
    final stats = task.latestStats;
    final children = stats?.children ?? [];

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Column(
        children: children.map((child) {
          final isRoot = child.pid == task.pid;
          return _buildChildRow(colors, child, isRoot);
        }).toList(),
      ),
    );
  }

  Widget _buildChildRow(
      AppColorScheme colors, ChildProcessStats child, bool isRoot) {
    final scale = core.settings.resourcesTextScale;
    final iconType = ProcessIcons.getIconType(child.name);

    return Container(
      height: 32 * scale,
      padding: EdgeInsets.only(left: 48 * scale, right: 12 * scale),
      decoration: BoxDecoration(
        border: Border(
            bottom:
                BorderSide(color: colors.border.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          // Process icon
          SizedBox(
            width: 24 * scale,
            child: _ProcessIcon(iconType: iconType, colors: colors, scale: scale),
          ),
          SizedBox(width: 8 * scale),
          // Process name
          SizedBox(
            width: 144 * scale,
            child: Row(
              children: [
                if (isRoot) ...[
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 4 * scale, vertical: 1 * scale),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'ROOT',
                      style: AppTheme.monoSmall.copyWith(
                        color: AppColors.info,
                        fontSize: 8 * scale,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 6 * scale),
                ],
                Expanded(
                  child: Text(
                    child.name,
                    style: AppTheme.monoSmall.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11 * scale,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // PID
          SizedBox(
            width: 80 * scale,
            child: Text(
              '${child.pid}',
              style: AppTheme.monoSmall.copyWith(
                color: colors.textMuted,
                fontSize: 11 * scale,
              ),
            ),
          ),
          // Spacer for children column
          SizedBox(width: 80 * scale),
          // CPU
          SizedBox(
            width: 80 * scale,
            child: Text(
              child.cpuPercent,
              style: AppTheme.monoSmall.copyWith(
                color: AppColors.info.withValues(alpha: 0.7),
                fontSize: 11 * scale,
              ),
            ),
          ),
          // Memory
          SizedBox(
            width: 100 * scale,
            child: Text(
              child.memoryMB,
              style: AppTheme.monoSmall.copyWith(
                color: AppColors.warning.withValues(alpha: 0.7),
                fontSize: 11 * scale,
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes % 60}m';
    } else if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds % 60}s';
    } else {
      return '${d.inSeconds}s';
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final AppColorScheme colors;
  final double scale;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.colors,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 8 * scale),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20 * scale, color: color),
          SizedBox(width: 12 * scale),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTheme.monoSmall.copyWith(
                  color: colors.textMuted,
                  fontSize: 10 * scale,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16 * scale,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SortableHeader extends StatelessWidget {
  final String label;
  final String column;
  final double width;
  final String currentSort;
  final bool ascending;
  final ValueChanged<String> onSort;
  final AppColorScheme colors;
  final double scale;

  const _SortableHeader({
    required this.label,
    required this.column,
    required this.width,
    required this.currentSort,
    required this.ascending,
    required this.onSort,
    required this.colors,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentSort == column;

    return InkWell(
      onTap: () => onSort(column),
      child: SizedBox(
        width: width,
        child: Row(
          children: [
            Text(
              label,
              style: AppTheme.monoSmall.copyWith(
                color: isActive ? colors.textPrimary : colors.textMuted,
                fontWeight: FontWeight.bold,
                fontSize: 12 * scale,
              ),
            ),
            if (isActive) ...[
              SizedBox(width: 4 * scale),
              Icon(
                ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12 * scale,
                color: colors.textPrimary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Process icon widget that shows appropriate icon for process type
class _ProcessIcon extends StatelessWidget {
  final String iconType;
  final AppColorScheme colors;
  final double scale;

  const _ProcessIcon({required this.iconType, required this.colors, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _getIconAndColor();
    return Icon(icon, size: 14 * scale, color: color);
  }

  (IconData, Color) _getIconAndColor() {
    switch (iconType) {
      case 'terminal':
        return (Icons.terminal, const Color(0xFF4EC9B0));
      case 'terminal_ps':
        return (Icons.terminal, const Color(0xFF012456));
      case 'python':
        return (Icons.code, const Color(0xFF3776AB));
      case 'node':
        return (Icons.hexagon_outlined, const Color(0xFF339933));
      case 'java':
        return (Icons.coffee, const Color(0xFFF89820));
      case 'ruby':
        return (Icons.diamond_outlined, const Color(0xFFCC342D));
      case 'go':
        return (Icons.directions_run, const Color(0xFF00ADD8));
      case 'rust':
        return (Icons.settings, const Color(0xFFDEA584));
      case 'dotnet':
        return (Icons.grid_view, const Color(0xFF512BD4));
      case 'npm':
        return (Icons.inventory_2_outlined, const Color(0xFFCB3837));
      case 'yarn':
        return (Icons.all_inclusive, const Color(0xFF2C8EBB));
      case 'pnpm':
        return (Icons.speed, const Color(0xFFF69220));
      case 'gradle':
        return (Icons.build_circle_outlined, const Color(0xFF02303A));
      case 'maven':
        return (Icons.view_module, const Color(0xFFC71A36));
      case 'vscode':
        return (Icons.code, const Color(0xFF007ACC));
      case 'git':
        return (Icons.merge_type, const Color(0xFFF05032));
      case 'docker':
        return (Icons.directions_boat, const Color(0xFF2496ED));
      case 'flutter':
        return (Icons.flutter_dash, const Color(0xFF02569B));
      case 'dart':
        return (Icons.flight, const Color(0xFF0175C2));
      case 'system':
        return (Icons.settings_applications, colors.textMuted);
      case 'folder':
        return (Icons.folder, const Color(0xFFFFCA28));
      default:
        return (Icons.memory, colors.textMuted);
    }
  }
}

/// Simple sparkline widget for showing data history
class _Sparkline extends StatelessWidget {
  final List<double> data;
  final Color color;

  const _Sparkline({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      painter: _SparklinePainter(data: data, color: color),
      size: Size.infinite,
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Find min/max for scaling
    double minVal = data.reduce((a, b) => a < b ? a : b);
    double maxVal = data.reduce((a, b) => a > b ? a : b);

    // Avoid division by zero
    if (maxVal == minVal) {
      maxVal = minVal + 1;
    }

    // Add some padding
    final range = maxVal - minVal;
    minVal -= range * 0.1;
    maxVal += range * 0.1;

    final path = Path();
    final stepX = size.width / (data.length - 1).clamp(1, double.infinity);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final normalized = (data[i] - minVal) / (maxVal - minVal);
      final y = size.height - (normalized * size.height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Draw a subtle fill under the line
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.color != color;
  }
}
