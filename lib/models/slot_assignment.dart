/// What type of content a slot can hold
enum SlotContentType {
  empty,
  tasksList,  // My Tasks panel (templates list)
  history,    // History panel
  terminal,   // Running task terminal (or log view)
  resources,  // Resource monitor panel
}

/// Assignment of content to a layout slot
class SlotAssignment {
  final int slotIndex;
  final SlotContentType contentType;
  final String? contentId; // taskId for terminal, historyId for log view

  const SlotAssignment({
    required this.slotIndex,
    this.contentType = SlotContentType.empty,
    this.contentId,
  });

  SlotAssignment copyWith({
    int? slotIndex,
    SlotContentType? contentType,
    String? contentId,
  }) {
    return SlotAssignment(
      slotIndex: slotIndex ?? this.slotIndex,
      contentType: contentType ?? this.contentType,
      contentId: contentId ?? this.contentId,
    );
  }

  bool get isEmpty => contentType == SlotContentType.empty;
  bool get isTasksList => contentType == SlotContentType.tasksList;
  bool get isHistory => contentType == SlotContentType.history;
  bool get isTerminal => contentType == SlotContentType.terminal;
  bool get isResources => contentType == SlotContentType.resources;

  Map<String, dynamic> toJson() => {
        'slotIndex': slotIndex,
        'contentType': contentType.name,
        'contentId': contentId,
      };

  factory SlotAssignment.fromJson(Map<String, dynamic> json) => SlotAssignment(
        slotIndex: json['slotIndex'] as int,
        contentType: SlotContentType.values.firstWhere(
          (e) => e.name == json['contentType'],
          orElse: () => SlotContentType.empty,
        ),
        contentId: json['contentId'] as String?,
      );
}
