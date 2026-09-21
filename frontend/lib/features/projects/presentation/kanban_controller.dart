import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/contracts/kanban.dart';
import 'package:touchin_flutter/contracts/project.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';

class ProjectKanbanController extends ChangeNotifier {
  ProjectKanbanController({TouchInApi? api}) : _api = api ?? TouchInApi();

  final TouchInApi _api;

  AuthContext? _authContext;
  List<ProjectSummary> _projects = const <ProjectSummary>[];
  List<ProjectMemberSummary> _projectMembers = const <ProjectMemberSummary>[];
  List<TaskRecord> _tasks = const <TaskRecord>[];
  KanbanBoard? _board;
  String? _selectedProjectId;
  bool _isLoading = true;
  bool _isLoadingBoard = false;
  int _pendingMutations = 0;
  String? _loadError;
  String? _boardError;
  int _selectionEpoch = 0;
  Future<void> _mutationTail = Future<void>.value();

  AuthContext? get authContext => _authContext;
  List<ProjectSummary> get projects => _projects;
  List<ProjectMemberSummary> get projectMembers => _projectMembers;
  List<TaskRecord> get tasks => _tasks;
  KanbanBoard? get board => _board;
  String? get selectedProjectId => _selectedProjectId;
  bool get isLoading => _isLoading;
  bool get isLoadingBoard => _isLoadingBoard;
  bool get isMutating => _pendingMutations > 0;
  String? get loadError => _loadError;
  String? get boardError => _boardError;

  ProjectSummary? get selectedProject {
    for (final project in _projects) {
      if (project.id == _selectedProjectId) {
        return project;
      }
    }
    return null;
  }

  bool get canManageStructure {
    final user = _authContext?.user;
    return user?.isManager == true ||
        user?.isAdmin == true ||
        user?.isSuperAdmin == true;
  }

  bool get canManageCards => canManageStructure;

  bool get currentEmployeeIsProjectMember {
    final employeeId = _authContext?.user.employeeId;
    if (employeeId == null || employeeId.isEmpty) {
      return false;
    }
    return _projectMembers.any((member) => member.employeeId == employeeId);
  }

  bool get canMoveCards => canManageStructure || currentEmployeeIsProjectMember;

  bool get canManageAssignees =>
      canManageStructure || currentEmployeeIsProjectMember;

  Future<void> start() async {
    final epoch = ++_selectionEpoch;
    _isLoading = true;
    _loadError = null;
    _boardError = null;
    notifyListeners();

    try {
      final authContext = await _api.getAuthContext();
      final projects = await _api.listProjects(status: ProjectStatus.active);
      if (epoch != _selectionEpoch) {
        return;
      }

      _authContext = authContext;
      _projects = List<ProjectSummary>.unmodifiable(projects);
      _selectedProjectId = projects.isEmpty ? null : projects.first.id;
      _isLoading = false;
      notifyListeners();

      final projectId = _selectedProjectId;
      if (projectId != null) {
        await _loadProjectSnapshot(projectId, epoch: epoch);
      }
    } catch (error) {
      if (epoch != _selectionEpoch) {
        return;
      }
      _isLoading = false;
      _loadError = _errorMessage(
        error,
        'Não foi possível carregar o Kanban.',
      );
      notifyListeners();
    }
  }

  Future<void> retry() => start();

  Future<void> selectProject(String projectId) async {
    if (projectId == _selectedProjectId && _boardError == null) {
      return;
    }

    final epoch = ++_selectionEpoch;
    _selectedProjectId = projectId;
    _projectMembers = const <ProjectMemberSummary>[];
    _tasks = const <TaskRecord>[];
    _board = null;
    _boardError = null;
    _isLoadingBoard = true;
    notifyListeners();

    await _loadProjectSnapshot(projectId, epoch: epoch, notifyLoading: false);
  }

  Future<void> reload() async {
    final projectId = _selectedProjectId;
    if (projectId == null) {
      return;
    }
    final epoch = ++_selectionEpoch;
    await _loadProjectSnapshot(projectId, epoch: epoch);
  }

  Future<void> _loadProjectSnapshot(
    String projectId, {
    required int epoch,
    bool notifyLoading = true,
  }) async {
    _isLoadingBoard = true;
    _boardError = null;
    if (notifyLoading) {
      notifyListeners();
    }

    try {
      final result = await Future.wait<dynamic>(<Future<dynamic>>[
        _api.listProjectMembers(projectId),
        _api.listTasks(projectId),
        _api.getKanbanBoard(projectId),
      ]);
      if (!_accepts(projectId, epoch)) {
        return;
      }

      _projectMembers = List<ProjectMemberSummary>.unmodifiable(
        result[0] as List<ProjectMemberSummary>,
      );
      _tasks = List<TaskRecord>.unmodifiable(result[1] as List<TaskRecord>);
      _board = result[2] as KanbanBoard;
      _isLoadingBoard = false;
      notifyListeners();
    } catch (error) {
      if (!_accepts(projectId, epoch)) {
        return;
      }
      _isLoadingBoard = false;
      _boardError = _errorMessage(
        error,
        'Não foi possível carregar o quadro.',
      );
      notifyListeners();
    }
  }

  Future<void> _reloadBoardAndTasks(String projectId) async {
    final epoch = _selectionEpoch;
    final result = await Future.wait<dynamic>(<Future<dynamic>>[
      _api.listTasks(projectId),
      _api.getKanbanBoard(projectId),
    ]);
    if (!_accepts(projectId, epoch)) {
      return;
    }
    _tasks = List<TaskRecord>.unmodifiable(result[0] as List<TaskRecord>);
    _board = result[1] as KanbanBoard;
    _boardError = null;
    notifyListeners();
  }

  Future<void> _reloadBoard(String projectId) async {
    final epoch = _selectionEpoch;
    final loaded = await _api.getKanbanBoard(projectId);
    if (!_accepts(projectId, epoch)) {
      return;
    }
    _board = loaded;
    _tasks = List<TaskRecord>.unmodifiable(loaded.taskRecords);
    notifyListeners();
  }

  Future<void> moveCard({
    required String taskId,
    required String toColumnId,
    required int toIndex,
  }) {
    final intentProjectId = _selectedProjectId;
    return _enqueueMutation<void>(() async {
      final projectId = intentProjectId;
      if (_selectedProjectId != projectId) {
        return;
      }
      final currentBoard = _board;
      if (projectId == null || currentBoard == null || !canMoveCards) {
        return;
      }

      final ordering = <String, List<String>>{
        for (final column in currentBoard.columns)
          column.id: column.cards.map((card) => card.id).toList(),
      };

      String? sourceColumnId;
      int sourceIndex = -1;
      for (final entry in ordering.entries) {
        final index = entry.value.indexOf(taskId);
        if (index >= 0) {
          sourceColumnId = entry.key;
          sourceIndex = index;
          entry.value.removeAt(index);
          break;
        }
      }
      final target = ordering[toColumnId];
      if (sourceColumnId == null || target == null) {
        return;
      }

      var targetIndex = toIndex.clamp(0, target.length).toInt();
      if (sourceColumnId == toColumnId && sourceIndex < targetIndex) {
        targetIndex -= 1;
      }
      if (sourceColumnId == toColumnId && sourceIndex == targetIndex) {
        return;
      }
      target.insert(targetIndex, taskId);

      final affected = <String, List<String>>{
        sourceColumnId: ordering[sourceColumnId]!,
        if (toColumnId != sourceColumnId) toColumnId: target,
      };

      try {
        final updated = await _api.reorderKanbanCards(
          projectId,
          expectedVersion: currentBoard.kanbanVersion,
          columnTaskIds: affected,
        );
        if (_selectedProjectId == projectId) {
          _board = updated;
          _tasks = List<TaskRecord>.unmodifiable(updated.taskRecords);
          _boardError = null;
        }
      } on ApiException catch (error) {
        await _handleConflict(error, projectId);
      }
    });
  }

  Future<void> moveColumn({
    required String columnId,
    required int toIndex,
  }) {
    final intentProjectId = _selectedProjectId;
    return _enqueueMutation<void>(() async {
      final projectId = intentProjectId;
      if (_selectedProjectId != projectId) {
        return;
      }
      final currentBoard = _board;
      if (projectId == null || currentBoard == null || !canManageStructure) {
        return;
      }

      final ids = currentBoard.columns.map((column) => column.id).toList();
      final sourceIndex = ids.indexOf(columnId);
      if (sourceIndex < 0) {
        return;
      }
      final id = ids.removeAt(sourceIndex);
      final targetIndex = toIndex.clamp(0, ids.length).toInt();
      ids.insert(targetIndex, id);
      if (sourceIndex == targetIndex) {
        return;
      }

      try {
        final updated = await _api.reorderKanbanColumns(
          projectId,
          expectedVersion: currentBoard.kanbanVersion,
          columnIds: ids,
        );
        if (_selectedProjectId == projectId) {
          _board = updated;
          _boardError = null;
        }
      } on ApiException catch (error) {
        await _handleConflict(error, projectId);
      }
    });
  }

  Future<void> createColumn(String name) {
    final intentProjectId = _selectedProjectId;
    return _enqueueMutation<void>(() async {
      final projectId = intentProjectId;
      if (_selectedProjectId != projectId) {
        return;
      }
      final currentBoard = _board;
      if (projectId == null || currentBoard == null || !canManageStructure) {
        return;
      }
      try {
        final updated = await _api.createKanbanColumn(
          projectId,
          name: name,
          expectedVersion: currentBoard.kanbanVersion,
        );
        if (_selectedProjectId == projectId) {
          _board = updated;
          _boardError = null;
        }
      } on ApiException catch (error) {
        await _handleConflict(error, projectId);
      }
    });
  }

  Future<void> renameColumn(String columnId, String name) {
    final intentProjectId = _selectedProjectId;
    return _enqueueMutation<void>(() async {
      final projectId = intentProjectId;
      if (_selectedProjectId != projectId) {
        return;
      }
      final currentBoard = _board;
      if (projectId == null || currentBoard == null || !canManageStructure) {
        return;
      }
      try {
        final updated = await _api.renameKanbanColumn(
          projectId,
          columnId,
          name: name,
          expectedVersion: currentBoard.kanbanVersion,
        );
        if (_selectedProjectId == projectId) {
          _board = updated;
          _boardError = null;
        }
      } on ApiException catch (error) {
        await _handleConflict(error, projectId);
      }
    });
  }

  Future<void> deleteColumn(String columnId) {
    final intentProjectId = _selectedProjectId;
    return _enqueueMutation<void>(() async {
      final projectId = intentProjectId;
      if (_selectedProjectId != projectId) {
        return;
      }
      final currentBoard = _board;
      if (projectId == null || currentBoard == null || !canManageStructure) {
        return;
      }
      try {
        final updated = await _api.deleteKanbanColumn(
          projectId,
          columnId,
          expectedVersion: currentBoard.kanbanVersion,
        );
        if (_selectedProjectId == projectId) {
          _board = updated;
          _boardError = null;
        }
      } on ApiException catch (error) {
        await _handleConflict(error, projectId);
      }
    });
  }

  Future<TaskRecord> createCard(TaskDraft draft) {
    return _enqueueMutation<TaskRecord>(() async {
      final projectId = _selectedProjectId;
      if (projectId == null || !canManageCards) {
        throw StateError('Nenhum projeto disponível para criar o card.');
      }
      final created = await _api.createTask(projectId, draft);
      if (_selectedProjectId == projectId) {
        await _reloadBoardAndTasks(projectId);
      }
      return created;
    });
  }

  Future<TaskRecord> updateCard(TaskRecord task, TaskDraft draft) {
    return _enqueueMutation<TaskRecord>(() async {
      if (!canManageCards) {
        throw StateError('Usuário sem permissão para editar cards.');
      }
      final updated = await _api.updateTask(task.projectId, task.id, draft);
      if (_selectedProjectId == task.projectId) {
        await _reloadBoardAndTasks(task.projectId);
      }
      return updated;
    });
  }

  Future<void> deleteCard(String taskId) {
    return _enqueueMutation<void>(() async {
      final projectId = _selectedProjectId;
      if (projectId == null || !canManageCards) {
        return;
      }
      await _api.deleteTask(projectId, taskId);
      if (_selectedProjectId == projectId) {
        await _reloadBoardAndTasks(projectId);
      }
    });
  }

  Future<void> addAssignee(String taskId, String employeeId) {
    return _enqueueMutation<void>(() async {
      final projectId = _selectedProjectId;
      if (projectId == null || !canManageAssignees) {
        return;
      }
      await _api.addKanbanAssignee(projectId, taskId, employeeId);
      if (_selectedProjectId == projectId) {
        await _reloadBoard(projectId);
      }
    });
  }

  Future<void> removeAssignee(String taskId, String employeeId) {
    return _enqueueMutation<void>(() async {
      final projectId = _selectedProjectId;
      if (projectId == null || !canManageAssignees) {
        return;
      }
      await _api.removeKanbanAssignee(projectId, taskId, employeeId);
      if (_selectedProjectId == projectId) {
        await _reloadBoard(projectId);
      }
    });
  }

  Future<T> _enqueueMutation<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _mutationTail = _mutationTail.then((_) async {
      _pendingMutations += 1;
      notifyListeners();
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        _pendingMutations -= 1;
        notifyListeners();
      }
    });
    return completer.future;
  }

  Future<void> _handleConflict(ApiException error, String projectId) async {
    if (error.statusCode != 409 || _selectedProjectId != projectId) {
      throw error;
    }
    _boardError =
        'O quadro mudou em outra sessão. O estado mais recente foi recarregado.';
    await _reloadBoard(projectId);
  }

  bool _accepts(String projectId, int epoch) {
    return epoch == _selectionEpoch && _selectedProjectId == projectId;
  }

  String _errorMessage(Object error, String fallback) {
    if (error is ApiException) {
      return error.message;
    }
    return fallback;
  }
}
