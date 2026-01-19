import 'task_step.dart';
import 'quick_action.dart';

/// A template is a saved task configuration that can be launched
class Template {
  final String id;
  final String name;
  final String command;
  final List<String> arguments;
  final String? workingDirectory;
  final String emoji;
  final String? description;
  final List<TaskStep> steps; // Automation steps (wait for pattern → send command)
  final List<QuickAction> quickActions; // User-defined quick action commands

  const Template({
    required this.id,
    required this.name,
    required this.command,
    this.arguments = const [],
    this.workingDirectory,
    this.emoji = '🚀',
    this.description,
    this.steps = const [],
    this.quickActions = const [],
  });

  /// Whether this template has automation steps
  bool get hasSteps => steps.isNotEmpty;

  /// Get all placeholders from command, arguments, and steps
  Set<String> get placeholders => PlaceholderExtractor.extractAll(
        command: command,
        arguments: arguments,
        steps: steps,
      );

  /// Whether this template requires placeholder input before running
  bool get requiresInput => placeholders.isNotEmpty;

  /// Get display-friendly command string
  String get displayCommand {
    if (arguments.isEmpty) return command;
    return '$command ${arguments.join(' ')}';
  }

  factory Template.fromJson(Map<String, dynamic> json) {
    return Template(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unnamed',
      command: json['command'] ?? json['executablePath'] ?? '',
      arguments: List<String>.from(json['arguments'] ?? []),
      workingDirectory: json['workingDirectory'],
      emoji: json['emoji'] ?? '🚀',
      description: json['description'],
      steps: (json['steps'] as List<dynamic>?)
              ?.map((s) => TaskStep.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      quickActions: (json['quickActions'] as List<dynamic>?)
              ?.map((a) => QuickAction.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'command': command,
        'arguments': arguments,
        if (workingDirectory != null) 'workingDirectory': workingDirectory,
        'emoji': emoji,
        if (description != null) 'description': description,
        if (steps.isNotEmpty) 'steps': steps.map((s) => s.toJson()).toList(),
        if (quickActions.isNotEmpty)
          'quickActions': quickActions.map((a) => a.toJson()).toList(),
      };

  Template copyWith({
    String? id,
    String? name,
    String? command,
    List<String>? arguments,
    String? workingDirectory,
    String? emoji,
    String? description,
    List<TaskStep>? steps,
    List<QuickAction>? quickActions,
  }) {
    return Template(
      id: id ?? this.id,
      name: name ?? this.name,
      command: command ?? this.command,
      arguments: arguments ?? this.arguments,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      emoji: emoji ?? this.emoji,
      description: description ?? this.description,
      steps: steps ?? this.steps,
      quickActions: quickActions ?? this.quickActions,
    );
  }
}
