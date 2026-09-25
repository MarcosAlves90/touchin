import 'package:touchin_flutter/contracts/audit.dart';
import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/contracts/contract_parsing.dart';
import 'package:touchin_flutter/contracts/employee.dart';
import 'package:touchin_flutter/contracts/kanban.dart';
import 'package:touchin_flutter/contracts/punch.dart';
import 'package:touchin_flutter/contracts/project.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/contracts/time_clock.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/storage/token_storage.dart';

class TouchInApi {
  TouchInApi({ApiClient? client, TokenStorage? tokenStorage})
      : _client = client ?? ApiClient(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  final ApiClient _client;
  final TokenStorage _tokenStorage;

  Future<AuthSession> login({
    required LoginCredentials credentials,
  }) async {
    final response = await _client.post(
      '/auth/login',
      body: credentials.toApiJson(),
    );

    return _persistSession(
      _parseContract(
        'login',
        () => AuthSession.fromJson(requireJsonMap(response, 'login response')),
      ),
    );
  }

  Future<AuthSession> registerCompany({
    required CompanyRegistrationDraft draft,
  }) async {
    final response = await _client.post(
      '/auth/register-company',
      body: draft.toApiJson(),
    );

    return _persistSession(
      _parseContract(
        'register-company',
        () => AuthSession.fromJson(
          requireJsonMap(response, 'register-company response'),
        ),
      ),
    );
  }

  Future<AuthContext> getAuthContext() async {
    final response = await _client.get('/auth/me', withAuth: true);
    return _parseContract(
      'auth/me',
      () => AuthContext.fromJson(requireJsonMap(response, 'auth/me response')),
    );
  }

  Future<void> logout() async {
    try {
      await _client.post('/auth/logout', withAuth: true);
    } finally {
      await _tokenStorage.clearAccessToken();
    }
  }

  Future<String> resetPassword({required String email}) async {
    final response = await _client.post(
      '/auth/reset-password',
      body: {'email': email},
    );

    final map = requireJsonMap(response, 'reset-password response');
    return requireString(map, 'message');
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.post(
      '/auth/change-password',
      withAuth: true,
      body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  Future<List<EmployeeProfile>> listEmployees() async {
    final response = await _client.get('/employees', withAuth: true);
    return _parseContract('employees', () {
      final payload = requireJsonList(response, 'employees response');
      return payload
          .map(
            (item) => EmployeeProfile.fromJson(
              requireJsonMap(item, 'employees[]'),
            ),
          )
          .toList();
    });
  }

  Future<EmployeeProfile> createEmployee(EmployeeDraft draft) async {
    final response = await _client.post(
      '/employees',
      withAuth: true,
      body: draft.toApiJson(),
    );

    return _parseContract(
      'create employee',
      () => EmployeeProfile.fromJson(
        requireJsonMap(response, 'create employee response'),
      ),
    );
  }

  Future<EmployeeProfile> updateEmployee(
    String employeeId,
    EmployeeDraft draft,
  ) async {
    final response = await _client.put(
      '/employees/$employeeId',
      withAuth: true,
      body: draft.toApiJson(),
    );

    return _parseContract(
      'update employee',
      () => EmployeeProfile.fromJson(
        requireJsonMap(response, 'update employee response'),
      ),
    );
  }

  Future<void> deleteEmployee(String employeeId) async {
    await _client.delete('/employees/$employeeId', withAuth: true);
  }

  Future<ManagedPunchPage> listManagedPunches(
    String employeeId, {
    int page = 1,
    int limit = 4,
  }) async {
    final response = await _client.get(
      '/time-clock/employees/$employeeId/punches',
      withAuth: true,
      queryParameters: <String, Object?>{
        'page': page,
        'limit': limit,
      },
    );

    return _parseContract('managed punches', () {
      return ManagedPunchPage.fromJson(
        requireJsonMap(response, 'managed punches response'),
      );
    });
  }

  Future<ManagedPunchRecord> createManagedPunch({
    required String employeeId,
    required ManagedPunchDraft draft,
  }) async {
    final response = await _client.post(
      '/time-clock/employees/$employeeId/punches',
      withAuth: true,
      body: draft.toCreateApiJson(),
    );

    return _parseContract(
      'create managed punch',
      () => ManagedPunchRecord.fromJson(
        requireJsonMap(response, 'create managed punch response'),
      ),
    );
  }

  Future<ManagedPunchRecord> updateManagedPunch({
    required String employeeId,
    required String punchId,
    required ManagedPunchDraft draft,
  }) async {
    final response = await _client.put(
      '/time-clock/employees/$employeeId/punches/$punchId',
      withAuth: true,
      body: draft.toUpdateApiJson(),
    );

    return _parseContract(
      'update managed punch',
      () => ManagedPunchRecord.fromJson(
        requireJsonMap(response, 'update managed punch response'),
      ),
    );
  }

  Future<void> deleteManagedPunch({
    required String employeeId,
    required String punchId,
  }) async {
    await _client.delete(
      '/time-clock/employees/$employeeId/punches/$punchId',
      withAuth: true,
    );
  }

  Future<TimeClockState> getMyTimeClockState({
    int page = 1,
    int limit = 4,
  }) async {
    final response = await _client.get(
      '/time-clock/me',
      withAuth: true,
      queryParameters: <String, Object?>{
        'page': page,
        'limit': limit,
      },
    );

    return _parseContract(
      'time-clock/me',
      () => TimeClockState.fromJson(
        requireJsonMap(response, 'time-clock/me response'),
      ),
    );
  }

  Future<PunchRecord> createPunch({
    required CreatePunchRequest request,
  }) async {
    final response = await _client.post(
      '/time-clock/me/punches',
      withAuth: true,
      body: request.toApiJson(),
    );

    return _parseContract(
      'create punch',
      () => PunchRecord.fromJson(
        requireJsonMap(response, 'create punch response'),
      ),
    );
  }

  Future<List<ProjectSummary>> listProjects({ProjectStatus? status}) async {
    final response = await _client.get(
      '/projects',
      withAuth: true,
      queryParameters: status == null
          ? null
          : <String, Object?>{'status': projectStatusToApi(status)},
    );
    return _parseContract('projects', () {
      final payload = requireJsonList(response, 'projects response');
      return payload
          .map(
            (item) => ProjectSummary.fromJson(
              requireJsonMap(item, 'projects[]'),
            ),
          )
          .toList();
    });
  }

  Future<ProjectSummary> createProject(ProjectDraft draft) async {
    final response = await _client.post(
      '/projects',
      withAuth: true,
      body: draft.toApiJson(),
    );
    return _parseContract(
      'create project',
      () => ProjectSummary.fromJson(
        requireJsonMap(response, 'create project response'),
      ),
    );
  }

  Future<ProjectSummary> updateProject(
    String projectId,
    ProjectDraft draft,
  ) async {
    final response = await _client.put(
      '/projects/$projectId',
      withAuth: true,
      body: draft.toApiJson(),
    );
    return _parseContract(
      'update project',
      () => ProjectSummary.fromJson(
        requireJsonMap(response, 'update project response'),
      ),
    );
  }

  Future<void> deleteProject(String projectId) async {
    await _client.delete('/projects/$projectId', withAuth: true);
  }

  Future<List<ProjectMemberSummary>> listProjectMembers(
      String projectId) async {
    final response = await _client.get(
      '/projects/$projectId/members',
      withAuth: true,
    );
    return _parseContract('project members', () {
      final payload = requireJsonList(response, 'project members response');
      return payload
          .map(
            (item) => ProjectMemberSummary.fromJson(
              requireJsonMap(item, 'project members[]'),
            ),
          )
          .toList();
    });
  }

  Future<ProjectMemberSummary> addProjectMember(
    String projectId,
    String employeeId,
  ) async {
    final response = await _client.post(
      '/projects/$projectId/members',
      withAuth: true,
      body: <String, dynamic>{'employeeId': employeeId},
    );
    return _parseContract(
      'add project member',
      () => ProjectMemberSummary.fromJson(
        requireJsonMap(response, 'add project member response'),
      ),
    );
  }

  Future<void> removeProjectMember(
    String projectId,
    String employeeId,
  ) async {
    await _client.delete(
      '/projects/$projectId/members/$employeeId',
      withAuth: true,
    );
  }

  Future<List<TaskRecord>> listTasks(String projectId) async {
    final response = await _client.get(
      '/projects/$projectId/tasks',
      withAuth: true,
    );
    return _parseContract('project tasks', () {
      final payload = requireJsonList(response, 'project tasks response');
      return payload
          .map(
            (item) => TaskRecord.fromJson(
              requireJsonMap(item, 'project tasks[]'),
            ),
          )
          .toList();
    });
  }

  Future<TaskRecord> createTask(String projectId, TaskDraft draft) async {
    final response = await _client.post(
      '/projects/$projectId/tasks',
      withAuth: true,
      body: draft.toApiJson(),
    );
    return _parseContract(
      'create task',
      () => TaskRecord.fromJson(
        requireJsonMap(response, 'create task response'),
      ),
    );
  }

  Future<TaskRecord> updateTask(
    String projectId,
    String taskId,
    TaskDraft draft,
  ) async {
    final response = await _client.put(
      '/projects/$projectId/tasks/$taskId',
      withAuth: true,
      body: draft.toApiJson(includeColumnId: false),
    );
    return _parseContract(
      'update task',
      () => TaskRecord.fromJson(
        requireJsonMap(response, 'update task response'),
      ),
    );
  }

  Future<List<TaskMemberSummary>> listTaskMembers(
    String projectId,
    String taskId,
  ) async {
    final response = await _client.get(
      '/projects/$projectId/tasks/$taskId/members',
      withAuth: true,
    );
    return _parseContract('task members', () {
      final payload = requireJsonList(response, 'task members response');
      return payload
          .map(
            (item) => TaskMemberSummary.fromJson(
              requireJsonMap(item, 'task members[]'),
            ),
          )
          .toList();
    });
  }

  Future<TaskMemberSummary> joinTask(
    String projectId,
    String taskId,
  ) async {
    final response = await _client.post(
      '/projects/$projectId/tasks/$taskId/members/me',
      withAuth: true,
    );
    return _parseContract(
      'join task',
      () => TaskMemberSummary.fromJson(
        requireJsonMap(response, 'join task response'),
      ),
    );
  }

  Future<void> leaveTask(String projectId, String taskId) async {
    await _client.delete(
      '/projects/$projectId/tasks/$taskId/members/me',
      withAuth: true,
    );
  }

  Future<TaskMemberSummary> addTaskMember(
    String projectId,
    String taskId,
    String employeeId,
  ) async {
    final response = await _client.post(
      '/projects/$projectId/tasks/$taskId/members',
      withAuth: true,
      body: <String, dynamic>{'employeeId': employeeId},
    );
    return _parseContract(
      'add task member',
      () => TaskMemberSummary.fromJson(
        requireJsonMap(response, 'add task member response'),
      ),
    );
  }

  Future<void> removeTaskMember(
    String projectId,
    String taskId,
    String employeeId,
  ) async {
    await _client.delete(
      '/projects/$projectId/tasks/$taskId/members/$employeeId',
      withAuth: true,
    );
  }

  Future<KanbanBoard> getKanbanBoard(String projectId) async {
    final response = await _client.get(
      '/projects/$projectId/kanban',
      withAuth: true,
    );
    return _parseContract(
      'project kanban',
      () => KanbanBoard.fromJson(
        requireJsonMap(response, 'project kanban response'),
      ),
    );
  }

  Future<KanbanBoard> createKanbanColumn(
    String projectId, {
    required String name,
    required int expectedVersion,
  }) async {
    final response = await _client.post(
      '/projects/$projectId/kanban/columns',
      withAuth: true,
      body: <String, dynamic>{
        'name': name,
        'expectedVersion': expectedVersion,
      },
    );
    return _parseContract(
      'create kanban column',
      () => KanbanBoard.fromJson(
        requireJsonMap(response, 'create kanban column response'),
      ),
    );
  }

  Future<KanbanBoard> renameKanbanColumn(
    String projectId,
    String columnId, {
    required String name,
    required int expectedVersion,
  }) async {
    final response = await _client.put(
      '/projects/$projectId/kanban/columns/$columnId',
      withAuth: true,
      body: <String, dynamic>{
        'name': name,
        'expectedVersion': expectedVersion,
      },
    );
    return _parseContract(
      'rename kanban column',
      () => KanbanBoard.fromJson(
        requireJsonMap(response, 'rename kanban column response'),
      ),
    );
  }

  Future<KanbanBoard> reorderKanbanColumns(
    String projectId, {
    required int expectedVersion,
    required List<String> columnIds,
  }) async {
    final response = await _client.put(
      '/projects/$projectId/kanban/columns/order',
      withAuth: true,
      body: <String, dynamic>{
        'expectedVersion': expectedVersion,
        'columnIds': columnIds,
      },
    );
    return _parseContract(
      'reorder kanban columns',
      () => KanbanBoard.fromJson(
        requireJsonMap(response, 'reorder kanban columns response'),
      ),
    );
  }

  Future<KanbanBoard> deleteKanbanColumn(
    String projectId,
    String columnId, {
    required int expectedVersion,
  }) async {
    final response = await _client.delete(
      '/projects/$projectId/kanban/columns/$columnId'
      '?expectedVersion=$expectedVersion',
      withAuth: true,
    );
    return _parseContract(
      'delete kanban column',
      () => KanbanBoard.fromJson(
        requireJsonMap(response, 'delete kanban column response'),
      ),
    );
  }

  Future<KanbanBoard> reorderKanbanCards(
    String projectId, {
    required int expectedVersion,
    required Map<String, List<String>> columnTaskIds,
  }) async {
    final response = await _client.put(
      '/projects/$projectId/kanban/cards/order',
      withAuth: true,
      body: <String, dynamic>{
        'expectedVersion': expectedVersion,
        'columns': columnTaskIds.entries
            .map(
              (entry) => <String, dynamic>{
                'columnId': entry.key,
                'taskIds': entry.value,
              },
            )
            .toList(),
      },
    );
    return _parseContract(
      'reorder kanban cards',
      () => KanbanBoard.fromJson(
        requireJsonMap(response, 'reorder kanban cards response'),
      ),
    );
  }

  Future<KanbanCard> addKanbanAssignee(
    String projectId,
    String taskId,
    String employeeId,
  ) async {
    final response = await _client.post(
      '/projects/$projectId/kanban/cards/$taskId/assignees/$employeeId',
      withAuth: true,
    );
    return _parseContract(
      'add kanban assignee',
      () => KanbanCard.fromJson(
        requireJsonMap(response, 'add kanban assignee response'),
      ),
    );
  }

  Future<KanbanCard> removeKanbanAssignee(
    String projectId,
    String taskId,
    String employeeId,
  ) async {
    final response = await _client.delete(
      '/projects/$projectId/kanban/cards/$taskId/assignees/$employeeId',
      withAuth: true,
    );
    return _parseContract(
      'remove kanban assignee',
      () => KanbanCard.fromJson(
        requireJsonMap(response, 'remove kanban assignee response'),
      ),
    );
  }

  Future<void> deleteTask(String projectId, String taskId) async {
    await _client.delete(
      '/projects/$projectId/tasks/$taskId',
      withAuth: true,
    );
  }


  Future<List<AuditEventResponse>> listAuditEvents({
    DateTime? startDate,
    DateTime? endDate,
    String? actorUserId,
    String? action,
    String? entityType,
    String? entityId,
    String? projectId,
  }) async {
    final queryParameters = <String, dynamic>{};
    if (startDate != null) queryParameters['start_date'] = startDate.toIso8601String();
    if (endDate != null) queryParameters['end_date'] = endDate.toIso8601String();
    if (actorUserId != null) queryParameters['actor_user_id'] = actorUserId;
    if (action != null) queryParameters['action'] = action;
    if (entityType != null) queryParameters['entity_type'] = entityType;
    if (entityId != null) queryParameters['entity_id'] = entityId;
    if (projectId != null) queryParameters['project_id'] = projectId;

    final response = await _client.get(
      '/audit-events',
      withAuth: true,
      queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
    );
    return _parseContract('audit events', () {
      final payload = requireJsonList(response, 'audit events response');
      return payload
          .map(
            (item) => AuditEventResponse.fromJson(
              requireJsonMap(item, 'audit events[]'),
            ),
          )
          .toList();
    });
  }

  Future<AuthSession> _persistSession(AuthSession session) async {
    await _tokenStorage.saveAuthSession(session);
    return session;
  }

  T _parseContract<T>(String endpoint, T Function() parser) {
    try {
      return parser();
    } on ContractParsingException catch (error) {
      throw ApiException(
        'Contrato invalido na resposta de $endpoint: ${error.message}',
      );
    }
  }
}
