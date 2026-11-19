import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/dev_preview/preview_controller.dart';

typedef PreviewJson = Map<String, dynamic>;

/// Fictional, linked fixtures. Dates, IDs and insertion order never use a clock
/// or random generator. Every mutable collection is recreated on reset.
class PreviewFixtures {
  PreviewFixtures() {
    reset();
  }

  static const date = '2026-11-18T12:00:00Z';
  static const companyId = 'preview-company';
  late List<PreviewJson> employees;
  late List<PreviewJson> projects;
  late List<PreviewJson> tasks;
  late List<PreviewJson> columns;
  late List<PreviewJson> projectMembers;
  late List<PreviewJson> taskMembers;
  late List<PreviewJson> punches;
  late List<PreviewJson> audit;
  int sequence = 100;
  int kanbanVersion = 1;

  AuthContext context(PreviewPersona persona) => AuthContext.fromJson({
        'company': {
          'id': companyId,
          'legalName': 'Oficina Aurora Fictícia — prévia local',
          'tradeName': 'Aurora • DADOS FICTÍCIOS',
          'cnpjMasked': '**.***.***/****-**',
          'emailMasked': 'p*****@example.invalid',
          'phoneMasked': '(**) *****-****',
        },
        'user': {
          'id': 'preview-user-${persona.name}',
          'email': '${persona.name}.previa@example.invalid',
          'role': persona.name,
          'employeeId': 'preview-employee-1',
        },
      });

  void reset() {
    sequence = 100;
    kanbanVersion = 1;
    const names = [
      'Lia Horizonte',
      'Caio',
      'Bia Estrela do Vale',
      'Ravi Jardim',
      'Nina',
      'Teo Vento',
      'Iara Lua',
      'Noa Ponte',
      'Dara Sol',
      'Ian Lago',
      'Eva Mar',
      'Otto Pedra',
      'Malu Brisa'
    ];
    employees = List.generate(
        names.length,
        (index) => {
              'id': 'preview-employee-${index + 1}',
              'hasAccount': true,
              'accessRole': index == 1 ? 'manager' : 'employee',
              'name': names[index],
              'role': index == 1 ? 'Coordenação' : 'Designer de produto',
              'department': index.isEven ? 'Produto' : 'Operações',
              'email': 'pessoa${index + 1}@example.invalid',
              'phone': '(00) 00000-0000',
              'unit': 'Ateliê Aurora (fictício)',
              'expectedShiftStart': '09:00',
              'expectedShiftEnd': '18:00',
              'status': [
                'active',
                'onboarding',
                'onLeave',
                'inactive'
              ][index % 4],
              'workMode': ['remote', 'hybrid', 'onsite'][index % 3],
              'roleLevel': index == 1 ? 'leadership' : 'specialist',
              'requiresLocationOnPunch': false,
              'trustedDeviceRequired': false,
              'todayWorkedMinutes': 180 + index * 12,
              'pendingAdjustments': index % 3,
              'lastPunchAt': date,
              'notes':
                  'Pessoa inteiramente fictícia para desenvolvimento local.',
            });
    projects = List.generate(
        3,
        (index) => {
              'id': 'preview-project-${index + 1}',
              'name': [
                'Portal Aurora — experiência acessível para equipes distribuídas',
                'Jardim',
                'Arquivo de ideias'
              ][index],
              'description': index == 0
                  ? 'Projeto fictício com textos extensos, tarefas e participantes para verificar a interface.'
                  : 'Ambiente de exploração local.',
              'taskEmployeeLimit': 5,
              'status': index == 2 ? 'inactive' : 'active',
              'createdAt': date,
              'updatedAt': date,
            });
    columns = [
      for (final project in projects)
        for (var index = 0; index < 3; index++)
          {
            'id': '${project['id']}-column-$index',
            'projectId': project['id'],
            'name': ['A fazer', 'Em andamento', 'Concluído'][index],
            'position': index,
            'createdAt': date,
            'updatedAt': date,
          }
    ];
    tasks = [
      for (var project = 1; project <= 3; project++)
        for (var index = 0;
            index <
                (project == 1
                    ? 14
                    : project == 2
                        ? 3
                        : 1);
            index++)
          {
            'id': 'preview-task-$project-$index',
            'projectId': 'preview-project-$project',
            'parentTaskId': index == 1 ? 'preview-task-$project-0' : null,
            'cardNumber': project * 100 + index + 1,
            'kanbanColumnId': 'preview-project-$project-column-${index % 3}',
            'kanbanPosition': index ~/ 3,
            'revision': 1,
            'name': index == 0
                ? 'Revisar navegação e acessibilidade em telas pequenas e grandes'
                : [
                    'Ajustar contraste',
                    'Documentar fluxo',
                    'Validar estados de carregamento'
                  ][index % 3],
            'description':
                'Tarefa fictícia ${index + 1}. Verifique filtros, textos longos e movimentação local.',
            'type': ['feature', 'bug', 'improvement'][index % 3],
            'createdAt': date,
            'updatedAt': date,
          }
    ];
    projectMembers = [
      for (final project in projects)
        for (final employee in employees.take(4))
          {
            'employeeId': employee['id'],
            'projectId': project['id'],
            'employeeName': employee['name'],
            'createdAt': date,
          }
    ];
    taskMembers = [
      for (final task in tasks)
        if (task['cardNumber'] % 2 == 0)
          {
            'employeeId': employees.first['id'],
            'taskId': task['id'],
            'employeeName': employees.first['name'],
            'createdAt': date,
          }
    ];
    punches = [
      for (final employee in employees)
        for (var index = 0; index < 8; index++)
          {
            'id': '${employee['id']}-punch-$index',
            'employeeId': employee['id'],
            'type': [
              'checkIn',
              'breakStart',
              'breakEnd',
              'checkOut'
            ][index % 4],
            'timestamp': '2026-11-${index < 4 ? '17' : '18'}T${[
              '09',
              '12',
              '13',
              '18'
            ][index % 4]}:00:00Z',
            'detail': 'Registro simulado em memória',
            'projectId': projects.first['id'],
            'location': null,
          }
    ];
    audit = List.generate(
        62,
        (index) => {
              'id': 'preview-audit-$index',
              'timestamp': date,
              'company_id': companyId,
              'actor_user_id': 'preview-user-admin',
              'project_id': projects.first['id'],
              'action': [
                'task.create',
                'task.update',
                'project.create'
              ][index % 3],
              'entity_type': index % 3 == 2 ? 'project' : 'task',
              'entity_id': index % 3 == 2
                  ? projects.first['id']
                  : tasks[index % tasks.length]['id'],
              'result': 'success',
              'metadata_payload': {'preview': true, 'fictional': true},
              'correlation_id': 'preview-correlation-$index',
            });
  }

  String nextId(String kind) => 'preview-$kind-${sequence++}';

  PreviewJson board(String projectId, {bool empty = false}) => {
        'projectId': projectId,
        'kanbanVersion': kanbanVersion,
        'columns': [
          for (final column
              in columns.where((c) => c['projectId'] == projectId))
            {
              ...column,
              'cards': empty
                  ? <PreviewJson>[]
                  : [
                      for (final task in tasks.where((t) =>
                          t['projectId'] == projectId &&
                          t['kanbanColumnId'] == column['id']))
                        card(task)
                    ],
            }
        ],
      };

  PreviewJson card(PreviewJson task) => {
        ...task,
        'assignees': taskMembers
            .where((member) => member['taskId'] == task['id'])
            .toList(),
      };
}
