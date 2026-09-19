import 'package:touchin_flutter/contracts/contract_parsing.dart';
import 'package:touchin_flutter/contracts/task.dart';

class KanbanCard {
  const KanbanCard({
    required this.id,
    required this.projectId,
    required this.parentTaskId,
    required this.cardNumber,
    required this.kanbanColumnId,
    required this.kanbanPosition,
    required this.name,
    required this.description,
    required this.type,
    required this.assignees,
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
  final List<TaskMemberSummary> assignees;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory KanbanCard.fromJson(JsonMap json) {
    final rawAssignees = requireJsonList(json['assignees'], 'assignees');
    return KanbanCard(
      id: requireString(json, 'id'),
      projectId: requireString(json, 'projectId'),
      parentTaskId: optionalString(json, 'parentTaskId'),
      cardNumber: requireInt(json, 'cardNumber'),
      kanbanColumnId: requireString(json, 'kanbanColumnId'),
      kanbanPosition: requireInt(json, 'kanbanPosition'),
      name: requireString(json, 'name'),
      description: requireString(json, 'description'),
      type: taskTypeFromApi(requireString(json, 'type')),
      assignees: rawAssignees
          .map(
            (item) => TaskMemberSummary.fromJson(
              requireJsonMap(item, 'assignees[]'),
            ),
          )
          .toList(),
      createdAt: requireDateTime(json, 'createdAt'),
      updatedAt: requireDateTime(json, 'updatedAt'),
    );
  }

  TaskRecord toTaskRecord() {
    return TaskRecord(
      id: id,
      projectId: projectId,
      parentTaskId: parentTaskId,
      cardNumber: cardNumber,
      kanbanColumnId: kanbanColumnId,
      kanbanPosition: kanbanPosition,
      name: name,
      description: description,
      type: type,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class KanbanColumn {
  const KanbanColumn({
    required this.id,
    required this.projectId,
    required this.name,
    required this.position,
    required this.cards,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String projectId;
  final String name;
  final int position;
  final List<KanbanCard> cards;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory KanbanColumn.fromJson(JsonMap json) {
    final rawCards = requireJsonList(json['cards'], 'cards');
    return KanbanColumn(
      id: requireString(json, 'id'),
      projectId: requireString(json, 'projectId'),
      name: requireString(json, 'name'),
      position: requireInt(json, 'position'),
      cards: rawCards
          .map(
            (item) => KanbanCard.fromJson(
              requireJsonMap(item, 'cards[]'),
            ),
          )
          .toList(),
      createdAt: requireDateTime(json, 'createdAt'),
      updatedAt: requireDateTime(json, 'updatedAt'),
    );
  }
}

class KanbanBoard {
  const KanbanBoard({
    required this.projectId,
    required this.kanbanVersion,
    required this.columns,
  });

  final String projectId;
  final int kanbanVersion;
  final List<KanbanColumn> columns;

  factory KanbanBoard.fromJson(JsonMap json) {
    final rawColumns = requireJsonList(json['columns'], 'columns');
    return KanbanBoard(
      projectId: requireString(json, 'projectId'),
      kanbanVersion: requireInt(json, 'kanbanVersion'),
      columns: rawColumns
          .map(
            (item) => KanbanColumn.fromJson(
              requireJsonMap(item, 'columns[]'),
            ),
          )
          .toList(),
    );
  }

  List<TaskRecord> get taskRecords => columns
      .expand((column) => column.cards)
      .map((card) => card.toTaskRecord())
      .toList();
}
