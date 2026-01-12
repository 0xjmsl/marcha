import 'template.dart';

/// A group of templates that can be launched together
class TaskGroup {
  final String id;
  final String name;
  final List<String> taskIds;
  final String emoji;

  const TaskGroup({
    required this.id,
    required this.name,
    required this.taskIds,
    this.emoji = '📁',
  });

  factory TaskGroup.fromJson(Map<String, dynamic> json) {
    return TaskGroup(
      id: json['id'],
      name: json['name'],
      taskIds: List<String>.from(json['taskIds'] ?? []),
      emoji: json['emoji'] ?? '📁',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'taskIds': taskIds,
    'emoji': emoji,
  };

  TaskGroup copyWith({
    String? id,
    String? name,
    List<String>? taskIds,
    String? emoji,
  }) {
    return TaskGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      taskIds: taskIds ?? this.taskIds,
      emoji: emoji ?? this.emoji,
    );
  }

  /// Get templates in order, filtering out any that no longer exist
  List<Template> getOrderedTemplates(List<Template> allTemplates) {
    final templateMap = {for (var t in allTemplates) t.id: t};
    return taskIds
        .map((id) => templateMap[id])
        .where((t) => t != null)
        .cast<Template>()
        .toList();
  }

  /// Number of templates in this group
  int get taskCount => taskIds.length;

  static TaskGroup empty() {
    return TaskGroup(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '',
      taskIds: [],
    );
  }
}
