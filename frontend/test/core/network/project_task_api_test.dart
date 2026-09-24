import 'package:touchin_flutter/contracts/project.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('project API uses backend contracts and authenticated endpoints',
      () async {
    final client = _ProjectTaskApiClient(
      getResponses: <String, dynamic>{
        '/projects': <dynamic>[_projectJson()],
        '/projects/project-01/members': <dynamic>[_projectMemberJson()],
      },
      postResponses: <String, dynamic>{
        '/projects': _projectJson(id: 'project-02', name: 'Novo projeto'),
        '/projects/project-01/members': _projectMemberJson(
          employeeId: 'emp-05',
          employeeName: 'Ana Lima',
        ),
      },
      putResponses: <String, dynamic>{
        '/projects/project-01': _projectJson(name: 'Projeto atualizado'),
      },
      deleteResponses: <String, dynamic>{
        '/projects/project-01': null,
        '/projects/project-01/members/emp-05': null,
      },
    );
    final api = TouchInApi(client: client);

    final projects = await api.listProjects();
    expect(projects.single.taskEmployeeLimit, 2);
    expect(projects.single.status, ProjectStatus.active);

    final created = await api.createProject(
      const ProjectDraft(
        name: 'Novo projeto',
        description: 'Descrição',
        taskEmployeeLimit: 3,
      ),
    );
    expect(created.id, 'project-02');
    expect(client.lastBody, <String, dynamic>{
      'name': 'Novo projeto',
      'description': 'Descrição',
      'taskEmployeeLimit': 3,
      'status': 'active',
    });

    final updated = await api.updateProject(
      'project-01',
      const ProjectDraft(
        name: 'Projeto atualizado',
        description: 'Descrição atualizada',
        taskEmployeeLimit: 2,
      ),
    );
    expect(updated.name, 'Projeto atualizado');
    expect(client.lastPath, '/projects/project-01');
    expect(client.lastWithAuth, isTrue);

    final projectMembers = await api.listProjectMembers('project-01');
    expect(projectMembers.single.employeeId, 'emp-04');

    final addedProjectMember = await api.addProjectMember(
      'project-01',
      'emp-05',
    );
    expect(addedProjectMember.employeeName, 'Ana Lima');
    expect(client.lastBody, <String, dynamic>{'employeeId': 'emp-05'});

    await api.removeProjectMember('project-01', 'emp-05');
    expect(client.lastPath, '/projects/project-01/members/emp-05');

    await api.deleteProject('project-01');
    expect(client.lastPath, '/projects/project-01');
  });

  test('task API covers hierarchy and membership endpoints', () async {
    final client = _ProjectTaskApiClient(
      getResponses: <String, dynamic>{
        '/projects/project-01/tasks': <dynamic>[_taskJson()],
        '/projects/project-01/tasks/task-01/members': <dynamic>[
          _memberJson(),
        ],
      },
      postResponses: <String, dynamic>{
        '/projects/project-01/tasks': _taskJson(id: 'task-02'),
        '/projects/project-01/tasks/task-01/members/me': _memberJson(),
        '/projects/project-01/tasks/task-01/members': _memberJson(
          employeeId: 'emp-05',
          employeeName: 'Ana Lima',
        ),
      },
      putResponses: <String, dynamic>{
        '/projects/project-01/tasks/task-01': _taskJson(name: 'Atualizada'),
      },
      deleteResponses: <String, dynamic>{
        '/projects/project-01/tasks/task-01/members/me': null,
        '/projects/project-01/tasks/task-01/members/emp-05': null,
      },
    );
    final api = TouchInApi(client: client);

    final tasks = await api.listTasks('project-01');
    expect(tasks.single.type, TaskType.feature);

    final created = await api.createTask(
      'project-01',
      const TaskDraft(
        name: 'Nova tarefa',
        description: 'Descrição',
        type: TaskType.bug,
        parentTaskId: 'task-parent',
        columnId: 'column-01',
      ),
    );
    expect(created.id, 'task-02');
    expect(client.lastBody, <String, dynamic>{
      'name': 'Nova tarefa',
      'description': 'Descrição',
      'type': 'bug',
      'parentTaskId': 'task-parent',
      'columnId': 'column-01',
    });

    final updated = await api.updateTask(
      'project-01',
      'task-01',
      const TaskDraft(
        name: 'Atualizada',
        description: 'Descrição atualizada',
        type: TaskType.improvement,
        columnId: 'column-01',
      ),
    );
    expect(updated.name, 'Atualizada');
    expect(client.lastBody, <String, dynamic>{
      'name': 'Atualizada',
      'description': 'Descrição atualizada',
      'type': 'improvement',
      'parentTaskId': null,
    });

    final members = await api.listTaskMembers('project-01', 'task-01');
    expect(members.single.employeeId, 'emp-04');

    await api.joinTask('project-01', 'task-01');
    expect(client.lastPath, '/projects/project-01/tasks/task-01/members/me');

    await api.addTaskMember('project-01', 'task-01', 'emp-05');
    expect(client.lastBody, <String, dynamic>{'employeeId': 'emp-05'});

    await api.removeTaskMember('project-01', 'task-01', 'emp-05');
    expect(
      client.lastPath,
      '/projects/project-01/tasks/task-01/members/emp-05',
    );

    await api.leaveTask('project-01', 'task-01');
    expect(client.lastPath, '/projects/project-01/tasks/task-01/members/me');
  });
}

Map<String, dynamic> _projectJson({
  String id = 'project-01',
  String name = 'Projeto principal',
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'description': 'Descrição do projeto',
    'taskEmployeeLimit': 2,
    'status': 'active',
    'createdAt': '2026-09-09T12:00:00Z',
    'updatedAt': '2026-09-09T12:00:00Z',
  };
}

Map<String, dynamic> _projectMemberJson({
  String employeeId = 'emp-04',
  String employeeName = 'João Lima',
}) {
  return <String, dynamic>{
    'employeeId': employeeId,
    'projectId': 'project-01',
    'employeeName': employeeName,
    'createdAt': '2026-09-09T12:00:00Z',
  };
}

Map<String, dynamic> _taskJson({
  String id = 'task-01',
  String name = 'Implementar tela',
}) {
  return <String, dynamic>{
    'id': id,
    'projectId': 'project-01',
    'parentTaskId': null,
    'name': name,
    'description': 'Descrição da tarefa',
    'type': 'feature',
    'createdAt': '2026-09-09T12:00:00Z',
    'updatedAt': '2026-09-09T12:00:00Z',
  };
}

Map<String, dynamic> _memberJson({
  String employeeId = 'emp-04',
  String employeeName = 'João Lima',
}) {
  return <String, dynamic>{
    'employeeId': employeeId,
    'taskId': 'task-01',
    'employeeName': employeeName,
    'createdAt': '2026-09-09T12:00:00Z',
  };
}

class _ProjectTaskApiClient extends ApiClient {
  _ProjectTaskApiClient({
    this.getResponses = const <String, dynamic>{},
    this.postResponses = const <String, dynamic>{},
    this.putResponses = const <String, dynamic>{},
    this.deleteResponses = const <String, dynamic>{},
  });

  final Map<String, dynamic> getResponses;
  final Map<String, dynamic> postResponses;
  final Map<String, dynamic> putResponses;
  final Map<String, dynamic> deleteResponses;

  String? lastPath;
  Object? lastBody;
  bool? lastWithAuth;

  @override
  Future<dynamic> get(
    String path, {
    bool withAuth = false,
    Map<String, Object?>? queryParameters,
  }) async {
    lastPath = path;
    lastWithAuth = withAuth;
    return getResponses[path];
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    bool withAuth = false,
  }) async {
    lastPath = path;
    lastBody = body;
    lastWithAuth = withAuth;
    return postResponses[path];
  }

  @override
  Future<dynamic> put(
    String path, {
    Object? body,
    bool withAuth = false,
  }) async {
    lastPath = path;
    lastBody = body;
    lastWithAuth = withAuth;
    return putResponses[path];
  }

  @override
  Future<dynamic> delete(String path, {bool withAuth = false}) async {
    lastPath = path;
    lastWithAuth = withAuth;
    return deleteResponses[path];
  }
}
