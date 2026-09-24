import 'package:touchin_flutter/contracts/contract_parsing.dart';

const int taskNameMaxLength = 160;
const int taskDescriptionMaxLength = 2000;

enum TaskType { bug, improvement, feature }

TaskType taskTypeFromApi(String value) {
  return switch (value) {
    'bug' => TaskType.bug,
    'improvement' => TaskType.improvement,
    'feature' => TaskType.feature,
    _ => throw ContractParsingException(
        'Unsupported task type value: $value',
      ),
  };
}

String taskTypeToApi(TaskType value) {
  return switch (value) {
    TaskType.bug => 'bug',
    TaskType.improvement => 'improvement',
    TaskType.feature => 'feature',
  };
}

class TaskRecord {
  const TaskRecord({
    required this.id,
    required this.projectId,
    required this.parentTaskId,
    this.cardNumber = 0,
    this.kanbanColumnId = '',
    this.kanbanPosition = 0,
    required this.name,
    required this.description,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String projectId;
  final String? parentTaskId;
  final int cardNumber;
  final String kanbanColumnId;
  final int kanbanPosition;
  final String name;
  final String description;
  final TaskType type;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TaskRecord.fromJson(JsonMap json) {
    return TaskRecord(
      id: requireString(json, 'id'),
      projectId: requireString(json, 'projectId'),
      parentTaskId: optionalString(json, 'parentTaskId'),
      cardNumber:
          json['cardNumber'] == null ? 0 : requireInt(json, 'cardNumber'),
      kanbanColumnId: json['kanbanColumnId'] == null
          ? ''
          : requireString(json, 'kanbanColumnId'),
      kanbanPosition: json['kanbanPosition'] == null
          ? 0
          : requireInt(json, 'kanbanPosition'),
      name: requireString(json, 'name'),
      description: requireString(json, 'description'),
      type: taskTypeFromApi(requireString(json, 'type')),
      createdAt: requireDateTime(json, 'createdAt'),
      updatedAt: requireDateTime(json, 'updatedAt'),
    );
  }
}

class TaskDraft {
  const TaskDraft({
    required this.name,
    required this.description,
    required this.type,
    this.parentTaskId,
    this.columnId,
  });

  final String name;
  final String description;
  final TaskType type;
  final String? parentTaskId;
  final String? columnId;

  factory TaskDraft.fromTask(TaskRecord task) {
    return TaskDraft(
      name: task.name,
      description: task.description,
      type: task.type,
      parentTaskId: task.parentTaskId,
      columnId: task.kanbanColumnId.isEmpty ? null : task.kanbanColumnId,
    );
  }

  JsonMap toApiJson({bool includeColumnId = true}) {
    return <String, dynamic>{
      'name': name.trim(),
      'description': description.trim(),
      'type': taskTypeToApi(type),
      'parentTaskId': parentTaskId,
      if (includeColumnId && columnId != null) 'columnId': columnId,
    };
  }
}

class TaskMemberSummary {
  const TaskMemberSummary({
    required this.employeeId,
    required this.taskId,
    required this.employeeName,
    required this.createdAt,
  });

  final String employeeId;
  final String taskId;
  final String employeeName;
  final DateTime createdAt;

  factory TaskMemberSummary.fromJson(JsonMap json) {
    return TaskMemberSummary(
      employeeId: requireString(json, 'employeeId'),
      taskId: requireString(json, 'taskId'),
      employeeName: requireString(json, 'employeeName'),
      createdAt: requireDateTime(json, 'createdAt'),
    );
  }
}
