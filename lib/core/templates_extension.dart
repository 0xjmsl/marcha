import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/template.dart';
import '../models/task_group.dart';
import 'core.dart';

/// Item type in display order
enum DisplayItemType { template, group }

/// Represents an item in the display order
class DisplayOrderItem {
  final DisplayItemType type;
  final String id;

  const DisplayOrderItem({required this.type, required this.id});

  factory DisplayOrderItem.template(String id) =>
      DisplayOrderItem(type: DisplayItemType.template, id: id);

  factory DisplayOrderItem.group(String id) =>
      DisplayOrderItem(type: DisplayItemType.group, id: id);

  factory DisplayOrderItem.fromJson(Map<String, dynamic> json) {
    return DisplayOrderItem(
      type: json['type'] == 'group' ? DisplayItemType.group : DisplayItemType.template,
      id: json['id'],
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type == DisplayItemType.group ? 'group' : 'template',
    'id': id,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DisplayOrderItem && type == other.type && id == other.id;

  @override
  int get hashCode => type.hashCode ^ id.hashCode;
}

/// Extension managing saved task templates and groups
class TemplatesExtension {
  final Core _core;

  TemplatesExtension(this._core);

  static const String _templatesFileName = 'templates.json';
  static const String _groupsFileName = 'task_groups.json';
  static const String _orderFileName = 'display_order.json';

  String get _templatesFilePath => '${Core.dataDir}\\$_templatesFileName';
  String get _groupsFilePath => '${Core.dataDir}\\$_groupsFileName';
  String get _orderFilePath => '${Core.dataDir}\\$_orderFileName';

  List<Template> _templates = [];
  List<TaskGroup> _groups = [];
  List<DisplayOrderItem> _displayOrder = [];

  // === TEMPLATES ===

  /// Get all templates
  List<Template> get all => List.unmodifiable(_templates);

  /// Get template by id
  Template? getById(String id) {
    return _templates.where((t) => t.id == id).firstOrNull;
  }

  /// Add a template
  Future<void> add(Template template) async {
    _templates.add(template);
    _core.notify();
    await _saveTemplates();
  }

  /// Remove a template
  Future<void> remove(String id) async {
    _templates.removeWhere((t) => t.id == id);
    // Also remove from any groups
    for (int i = 0; i < _groups.length; i++) {
      if (_groups[i].taskIds.contains(id)) {
        _groups[i] = _groups[i].copyWith(
          taskIds: _groups[i].taskIds.where((tid) => tid != id).toList(),
        );
      }
    }
    _core.notify();
    await Future.wait([_saveTemplates(), _saveGroups()]);
  }

  /// Update a template
  Future<void> update(Template template) async {
    final index = _templates.indexWhere((t) => t.id == template.id);
    if (index >= 0) {
      _templates[index] = template;
      _core.notify();
      await _saveTemplates();
    }
  }

  // === GROUPS ===

  /// Get all groups
  List<TaskGroup> get groups => List.unmodifiable(_groups);

  /// Get group by id
  TaskGroup? getGroupById(String id) {
    return _groups.where((g) => g.id == id).firstOrNull;
  }

  /// Add a group
  Future<void> addGroup(TaskGroup group) async {
    _groups.add(group);
    _core.notify();
    await _saveGroups();
  }

  /// Remove a group
  Future<void> removeGroup(String id) async {
    _groups.removeWhere((g) => g.id == id);
    _core.notify();
    await _saveGroups();
  }

  /// Update a group
  Future<void> updateGroup(TaskGroup group) async {
    final index = _groups.indexWhere((g) => g.id == group.id);
    if (index >= 0) {
      _groups[index] = group;
      _core.notify();
      await _saveGroups();
    }
  }

  /// Get templates not in any group
  List<Template> getUngroupedTemplates() {
    final groupedIds = _groups.expand((g) => g.taskIds).toSet();
    return _templates.where((t) => !groupedIds.contains(t.id)).toList();
  }

  // === DISPLAY ORDER ===

  /// Get the display order (groups and ungrouped templates in order)
  List<DisplayOrderItem> get displayOrder {
    _rebuildDisplayOrderIfNeeded();
    return List.unmodifiable(_displayOrder);
  }

  /// Rebuild display order if items are missing or stale
  void _rebuildDisplayOrderIfNeeded() {
    final groupedIds = _groups.expand((g) => g.taskIds).toSet();
    final ungroupedIds = _templates
        .where((t) => !groupedIds.contains(t.id))
        .map((t) => t.id)
        .toSet();
    final groupIds = _groups.map((g) => g.id).toSet();

    // Check if order is valid
    final orderTemplateIds = _displayOrder
        .where((o) => o.type == DisplayItemType.template)
        .map((o) => o.id)
        .toSet();
    final orderGroupIds = _displayOrder
        .where((o) => o.type == DisplayItemType.group)
        .map((o) => o.id)
        .toSet();

    final needsRebuild = orderTemplateIds.length != ungroupedIds.length ||
        orderGroupIds.length != groupIds.length ||
        !ungroupedIds.every(orderTemplateIds.contains) ||
        !groupIds.every(orderGroupIds.contains);

    if (needsRebuild) {
      // Keep valid items in current order, add missing at end
      final newOrder = <DisplayOrderItem>[];

      // Keep existing items that are still valid
      for (final item in _displayOrder) {
        if (item.type == DisplayItemType.group && groupIds.contains(item.id)) {
          newOrder.add(item);
        } else if (item.type == DisplayItemType.template && ungroupedIds.contains(item.id)) {
          newOrder.add(item);
        }
      }

      // Add missing groups
      for (final id in groupIds) {
        if (!newOrder.any((o) => o.type == DisplayItemType.group && o.id == id)) {
          newOrder.add(DisplayOrderItem.group(id));
        }
      }

      // Add missing templates
      for (final id in ungroupedIds) {
        if (!newOrder.any((o) => o.type == DisplayItemType.template && o.id == id)) {
          newOrder.add(DisplayOrderItem.template(id));
        }
      }

      _displayOrder = newOrder;
    }
  }

  /// Reorder items in display order
  Future<void> reorderDisplay(int oldIndex, int newIndex) async {
    _rebuildDisplayOrderIfNeeded();
    if (oldIndex < 0 || oldIndex >= _displayOrder.length) return;
    if (newIndex < 0 || newIndex > _displayOrder.length) return;
    if (oldIndex == newIndex) return;

    final item = _displayOrder.removeAt(oldIndex);
    if (newIndex > oldIndex) newIndex--;
    _displayOrder.insert(newIndex, item);
    _core.notify();
    await _saveDisplayOrder();
  }

  /// Ungroup a template and place it at a specific position in display order
  Future<void> ungroupTemplate(String templateId, String fromGroupId, int displayIndex) async {
    // Remove from group
    final groupIndex = _groups.indexWhere((g) => g.id == fromGroupId);
    if (groupIndex >= 0) {
      final group = _groups[groupIndex];
      _groups[groupIndex] = group.copyWith(
        taskIds: group.taskIds.where((id) => id != templateId).toList(),
      );
    }

    // Add to display order at position
    _rebuildDisplayOrderIfNeeded();
    final item = DisplayOrderItem.template(templateId);
    // Remove if already exists (shouldn't, but just in case)
    _displayOrder.removeWhere((o) => o.type == DisplayItemType.template && o.id == templateId);
    // Insert at position
    final insertIndex = displayIndex.clamp(0, _displayOrder.length);
    _displayOrder.insert(insertIndex, item);

    _core.notify();
    await Future.wait([_saveGroups(), _saveDisplayOrder()]);
  }

  /// Duplicate a template with a new ID
  Future<Template> duplicate(String id) async {
    final original = getById(id);
    if (original == null) {
      throw ArgumentError('Template not found: $id');
    }
    final copy = original.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '${original.name} (copy)',
    );
    _templates.add(copy);
    _core.notify();
    await _saveTemplates();
    return copy;
  }

  /// Reorder templates in the list
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _templates.length) return;
    if (newIndex < 0 || newIndex >= _templates.length) return;
    if (oldIndex == newIndex) return;

    final item = _templates.removeAt(oldIndex);
    _templates.insert(newIndex, item);
    _core.notify();
    await _saveTemplates();
  }

  /// Add a template to a group
  Future<void> addToGroup(String templateId, String groupId) async {
    final groupIndex = _groups.indexWhere((g) => g.id == groupId);
    if (groupIndex < 0) return;

    final group = _groups[groupIndex];
    if (group.taskIds.contains(templateId)) return; // Already in group

    _groups[groupIndex] = group.copyWith(
      taskIds: [...group.taskIds, templateId],
    );
    _core.notify();
    await _saveGroups();
  }

  /// Remove a template from a group
  Future<void> removeFromGroup(String templateId, String groupId) async {
    final groupIndex = _groups.indexWhere((g) => g.id == groupId);
    if (groupIndex < 0) return;

    final group = _groups[groupIndex];
    _groups[groupIndex] = group.copyWith(
      taskIds: group.taskIds.where((id) => id != templateId).toList(),
    );
    _core.notify();
    await _saveGroups();
  }

  /// Reorder templates within a group
  Future<void> reorderInGroup(String groupId, int oldIndex, int newIndex) async {
    final groupIndex = _groups.indexWhere((g) => g.id == groupId);
    if (groupIndex < 0) return;

    final group = _groups[groupIndex];
    final taskIds = List<String>.from(group.taskIds);

    if (oldIndex < 0 || oldIndex >= taskIds.length) return;
    if (newIndex < 0 || newIndex >= taskIds.length) return;
    if (oldIndex == newIndex) return;

    final item = taskIds.removeAt(oldIndex);
    taskIds.insert(newIndex, item);

    _groups[groupIndex] = group.copyWith(taskIds: taskIds);
    _core.notify();
    await _saveGroups();
  }

  // === PERSISTENCE ===

  /// Load templates and groups from disk
  Future<void> load() async {
    await Future.wait([_loadTemplates(), _loadGroups(), _loadDisplayOrder()]);
    _rebuildDisplayOrderIfNeeded();
  }

  /// Save all to disk
  Future<void> save() async {
    await Future.wait([_saveTemplates(), _saveGroups(), _saveDisplayOrder()]);
  }

  Future<void> _loadTemplates() async {
    try {
      final file = File(_templatesFilePath);
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = json.decode(jsonString);
        _templates = jsonList.map((j) => Template.fromJson(j)).toList();
        debugPrint('TemplatesExtension: Loaded ${_templates.length} templates');
      }
    } catch (e) {
      debugPrint('TemplatesExtension: Error loading templates: $e');
      _templates = [];
    }
  }

  Future<void> _loadGroups() async {
    try {
      final file = File(_groupsFilePath);
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = json.decode(jsonString);
        _groups = jsonList.map((j) => TaskGroup.fromJson(j)).toList();
        debugPrint('TemplatesExtension: Loaded ${_groups.length} groups');
      }
    } catch (e) {
      debugPrint('TemplatesExtension: Error loading groups: $e');
      _groups = [];
    }
  }

  Future<void> _saveTemplates() async {
    try {
      final file = File(_templatesFilePath);
      final jsonString = json.encode(_templates.map((t) => t.toJson()).toList());
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint('TemplatesExtension: Error saving templates: $e');
    }
  }

  Future<void> _saveGroups() async {
    try {
      final file = File(_groupsFilePath);
      final jsonString = json.encode(_groups.map((g) => g.toJson()).toList());
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint('TemplatesExtension: Error saving groups: $e');
    }
  }

  Future<void> _loadDisplayOrder() async {
    try {
      final file = File(_orderFilePath);
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = json.decode(jsonString);
        _displayOrder = jsonList.map((j) => DisplayOrderItem.fromJson(j)).toList();
        debugPrint('TemplatesExtension: Loaded ${_displayOrder.length} order items');
      }
    } catch (e) {
      debugPrint('TemplatesExtension: Error loading display order: $e');
      _displayOrder = [];
    }
  }

  Future<void> _saveDisplayOrder() async {
    try {
      final file = File(_orderFilePath);
      final jsonString = json.encode(_displayOrder.map((o) => o.toJson()).toList());
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint('TemplatesExtension: Error saving display order: $e');
    }
  }
}
