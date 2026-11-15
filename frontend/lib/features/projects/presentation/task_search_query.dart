import 'package:touchin_flutter/contracts/kanban.dart';
import 'package:touchin_flutter/contracts/task.dart';

class TaskSearchQuery {
  TaskSearchQuery._({
    required this.rawText,
    required this.types,
    required this.columnIds,
    required this.textTerms,
    required this.cardNumber,
  });

  factory TaskSearchQuery.parse(
    String input, {
    required List<KanbanColumn> columns,
  }) {
    final tokens = _normalize(input)
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList();
    final searchable = List<String>.of(tokens);
    final numberMatches = <int>[];
    for (var i = 0; i < searchable.length; i++) {
      final match = RegExp(r'^#(\d+)$').firstMatch(searchable[i]);
      if (match != null) numberMatches.add(i);
    }
    final cardNumber = numberMatches.length == 1
        ? int.tryParse(searchable[numberMatches.single].substring(1))
        : null;
    if (cardNumber != null) searchable[numberMatches.single] = '';

    final typePositions = <int, TaskType>{};
    for (var i = 0; i < searchable.length; i++) {
      final token = searchable[i];
      final explicit = RegExp(r'^(?:tipo|type):(.+)$').firstMatch(token);
      final type =
          explicit == null ? _types[token] : _types[explicit.group(1)!];
      if (type != null) typePositions[i] = type;
    }
    final uniqueTypes = typePositions.values.toSet();
    final types = uniqueTypes.length == 1 ? uniqueTypes : <TaskType>{};
    if (types.isNotEmpty) {
      for (final position in typePositions.keys) {
        searchable[position] = '';
      }
    }

    final statuses = <String, Set<String>>{};
    for (final column in columns) {
      final name = _normalize(column.name);
      if (name.isNotEmpty) {
        statuses.putIfAbsent(name, () => <String>{}).add(column.id);
      }
    }
    final statusPositions = <int, Set<String>>{};
    for (final entry in statuses.entries) {
      final nameTokens = entry.key.split(' ');
      for (var start = 0;
          start <= searchable.length - nameTokens.length;
          start++) {
        final candidate =
            searchable.skip(start).take(nameTokens.length).toList();
        if (candidate.length == nameTokens.length &&
            List<bool>.generate(
              nameTokens.length,
              (offset) => candidate[offset] == nameTokens[offset],
            ).every((matches) => matches)) {
          for (var offset = 0; offset < nameTokens.length; offset++) {
            statusPositions.update(
              start + offset,
              (ids) => <String>{...ids, ...entry.value},
              ifAbsent: () => entry.value,
            );
          }
        }
      }
    }
    final statusIds = statusPositions.values.expand((ids) => ids).toSet();
    final columnIds = statusIds.length == 1 ? statusIds : <String>{};
    if (columnIds.isNotEmpty) {
      for (final position in statusPositions.keys) {
        searchable[position] = '';
      }
    }

    final textTerms = searchable
        .where((token) => token.isNotEmpty && !_connectors.contains(token))
        .toList();
    return TaskSearchQuery._(
      rawText: input,
      types: types,
      columnIds: columnIds,
      textTerms: textTerms,
      cardNumber: cardNumber,
    );
  }

  static const Map<String, TaskType> _types = <String, TaskType>{
    'bug': TaskType.bug,
    'bugs': TaskType.bug,
    'defeito': TaskType.bug,
    'defeitos': TaskType.bug,
    'erro': TaskType.bug,
    'erros': TaskType.bug,
    'improvement': TaskType.improvement,
    'improvements': TaskType.improvement,
    'melhoria': TaskType.improvement,
    'melhorias': TaskType.improvement,
    'feature': TaskType.feature,
    'features': TaskType.feature,
    'funcionalidade': TaskType.feature,
    'funcionalidades': TaskType.feature,
    'recurso': TaskType.feature,
    'recursos': TaskType.feature,
  };

  static const Set<String> _connectors = <String>{
    'a',
    'as',
    'com',
    'da',
    'das',
    'de',
    'do',
    'dos',
    'e',
    'em',
    'na',
    'nas',
    'no',
    'nos',
    'o',
    'os',
    'para',
    'por',
  };

  final String rawText;
  final Set<TaskType> types;
  final Set<String> columnIds;
  final List<String> textTerms;
  final int? cardNumber;

  bool get isActive =>
      types.isNotEmpty ||
      columnIds.isNotEmpty ||
      textTerms.isNotEmpty ||
      cardNumber != null;

  bool matches(KanbanCard card, KanbanColumn column) {
    if (types.isNotEmpty && !types.contains(card.type)) return false;
    if (columnIds.isNotEmpty && !columnIds.contains(column.id)) return false;
    if (cardNumber != null && card.cardNumber != cardNumber) return false;
    final text = _normalize('${card.name} ${card.description}');
    return textTerms.every(text.contains);
  }

  static String normalize(String value) => _normalize(value);

  static String _normalize(String value) {
    var result = value.toLowerCase();
    const replacements = <String, String>{
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
    };
    for (final entry in replacements.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
