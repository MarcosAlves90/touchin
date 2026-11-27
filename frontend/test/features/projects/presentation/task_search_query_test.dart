import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/contracts/kanban.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/features/projects/presentation/task_search_query.dart';

void main() {
  final columns = <KanbanColumn>[
    KanbanColumn(
      id: 'todo',
      projectId: 'project-1',
      name: 'A fazer',
      position: 0,
      cards: const <KanbanCard>[],
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
    KanbanColumn(
      id: 'doing',
      projectId: 'project-1',
      name: 'Em andamento',
      position: 1,
      cards: const <KanbanCard>[],
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
  ];

  test('recognizes a task type and a status from the current board', () {
    final query = TaskSearchQuery.parse(
      'bugs de login em andamento',
      columns: columns,
    );

    expect(query.types, <TaskType>{TaskType.bug});
    expect(query.columnIds, <String>{'doing'});
    expect(query.textTerms, <String>['login']);
    expect(query.cardNumber, isNull);
  });

  test('normalizes accents and recognizes Portuguese task-type synonyms', () {
    final query = TaskSearchQuery.parse(
      'MELHORIAS EM ANDAMENTO',
      columns: columns,
    );

    expect(query.types, <TaskType>{TaskType.improvement});
    expect(query.columnIds, <String>{'doing'});
    expect(query.textTerms, isEmpty);
  });

  test('keeps overlapping current-board statuses as literal text', () {
    final query = TaskSearchQuery.parse(
      'A fazer pacote',
      columns: <KanbanColumn>[
        ...columns,
        _column('package', 'A fazer pacote', 2),
      ],
    );

    expect(query.columnIds, isEmpty);
    expect(query.textTerms, <String>['fazer', 'pacote']);
  });

  test('keeps duplicate and overlapping status names as literal text', () {
    final query = TaskSearchQuery.parse(
      'A fazer',
      columns: <KanbanColumn>[
        ...columns,
        _column('todo-duplicate', 'A fazer', 2),
        _column('doing-unique', 'fazer', 3),
      ],
    );

    expect(query.columnIds, isEmpty);
    expect(query.textTerms, <String>['fazer']);
  });

  test('preserves explicit type syntax and card numbers', () {
    final query = TaskSearchQuery.parse(
      'tipo:bug login #42',
      columns: columns,
    );

    expect(query.types, <TaskType>{TaskType.bug});
    expect(query.columnIds, isEmpty);
    expect(query.textTerms, <String>['login']);
    expect(query.cardNumber, 42);
  });

  test('keeps unknown terms as literal text instead of inventing filters', () {
    final query = TaskSearchQuery.parse(
      'texto desconhecido',
      columns: columns,
    );

    expect(query.types, isEmpty);
    expect(query.columnIds, isEmpty);
    expect(query.textTerms, <String>['texto', 'desconhecido']);
    expect(query.cardNumber, isNull);
  });

  test('keeps ambiguous task types as literal text', () {
    final query = TaskSearchQuery.parse('bug feature', columns: columns);

    expect(query.types, isEmpty);
    expect(query.columnIds, isEmpty);
    expect(query.textTerms, <String>['bug', 'feature']);
    expect(query.matches(_card(name: 'bug feature'), columns[0]), isTrue);
    expect(query.matches(_card(name: 'bug only'), columns[0]), isFalse);
  });

  test('keeps a bare type token literal when it matches a current status', () {
    final bugColumn = _column('bug-status', 'Bug', 2);
    final allColumns = <KanbanColumn>[...columns, bugColumn];
    final query = TaskSearchQuery.parse('bug', columns: allColumns);

    expect(query.types, isEmpty);
    expect(query.columnIds, isEmpty);
    expect(query.textTerms, <String>['bug']);
    expect(
      query.matches(
        _card(
          name: 'Existing task',
          type: TaskType.feature,
          columnId: bugColumn.id,
        ),
        bugColumn,
      ),
      isFalse,
    );
    expect(
      query.matches(
        _card(name: 'Bug report', type: TaskType.feature),
        columns[0],
      ),
      isTrue,
    );
    expect(
      TaskSearchQuery.parse('type:bug', columns: allColumns).types,
      <TaskType>{TaskType.bug},
    );
  });

  test('keeps a full status phrase literal when it collides with a bare type', () {
    final allColumns = <KanbanColumn>[
      ...columns,
      _column('bug-status', 'Bug Status', 2),
    ];
    final literal = TaskSearchQuery.parse('bug status', columns: allColumns);

    expect(literal.types, isEmpty);
    expect(literal.columnIds, isEmpty);
    expect(literal.textTerms, <String>['bug', 'status']);
    expect(
      TaskSearchQuery.parse('type:bug', columns: allColumns).types,
      <TaskType>{TaskType.bug},
    );
  });

  test('matches title or description without case or accent sensitivity', () {
    final query = TaskSearchQuery.parse('login', columns: columns);
    final titleCard = _card(name: 'Falha no LOGIN');
    final descriptionCard = _card(description: 'Erro no login ao salvar');
    final otherCard = _card(name: 'Ajustar permissões');

    expect(query.matches(titleCard, columns[0]), isTrue);
    expect(query.matches(descriptionCard, columns[0]), isTrue);
    expect(query.matches(otherCard, columns[0]), isFalse);
  });
}

KanbanColumn _column(String id, String name, int position) => KanbanColumn(
      id: id,
      projectId: 'project-1',
      name: name,
      position: position,
      cards: const <KanbanCard>[],
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

KanbanCard _card({
  String name = 'Tarefa',
  String description = '',
  TaskType type = TaskType.bug,
  int cardNumber = 1,
  String columnId = 'todo',
}) =>
    KanbanCard(
      id: 'task-$cardNumber',
      projectId: 'project-1',
      parentTaskId: null,
      cardNumber: cardNumber,
      kanbanColumnId: columnId,
      kanbanPosition: cardNumber - 1,
      name: name,
      description: description,
      type: type,
      assignees: const <TaskMemberSummary>[],
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
