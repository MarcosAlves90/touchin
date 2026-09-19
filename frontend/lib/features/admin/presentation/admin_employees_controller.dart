import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/contracts/employee.dart';
import 'package:touchin_flutter/contracts/time_clock.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:flutter/material.dart';

class AdminEmployeesController extends ChangeNotifier {
  AdminEmployeesController({TouchInApi? api}) : _api = api ?? TouchInApi();

  final TouchInApi _api;

  final TextEditingController searchController = TextEditingController();
  List<EmployeeProfile> employees = <EmployeeProfile>[];
  AuthContext? authContext;
  EmployeeFilter filter = EmployeeFilter.all;
  String searchQuery = '';
  int employeesPage = 1;
  int employeesPageSize = 8;
  String? selectedEmployeeId;
  List<ManagedPunchRecord> employeePunches = <ManagedPunchRecord>[];
  int employeePunchesPage = 1;
  int employeePunchesPageSize = 4;
  int employeePunchesTotal = 0;
  int employeePunchesTotalPages = 1;
  bool employeePunchesHasPrevious = false;
  bool employeePunchesHasNext = false;
  bool isLoadingEmployeePunches = false;
  String? employeePunchesError;
  bool isLoading = true;
  String? loadError;

  Future<void> start() async {
    await loadEmployees();
  }

  Future<void> loadEmployees() async {
    isLoading = true;
    loadError = null;
    notifyListeners();

    try {
      final employeesFuture = _api.listEmployees();
      final authContextFuture = _loadAuthContextSafely();
      final loadedEmployees = await employeesFuture;
      final loadedAuthContext = await authContextFuture;

      employees = loadedEmployees;
      authContext = loadedAuthContext;
      employeesPage = 1;
      if (selectedEmployeeId == null && employees.isNotEmpty) {
        selectedEmployeeId = employees.first.id;
      }
      isLoading = false;
      notifyListeners();
      if (selectedEmployeeId != null) {
        await loadEmployeePunches(selectedEmployeeId!, page: 1);
      }
    } on ApiException catch (error) {
      isLoading = false;
      loadError = error.message;
      notifyListeners();
    } catch (_) {
      isLoading = false;
      loadError = 'Não foi possível carregar os funcionários.';
      notifyListeners();
    }
  }

  Future<AuthContext?> _loadAuthContextSafely() async {
    try {
      return await _api.getAuthContext();
    } on ApiException {
      return null;
    } catch (_) {
      return null;
    }
  }

  List<EmployeeProfile> get visibleEmployees {
    final normalizedQuery = searchQuery.trim().toLowerCase();
    final currentUserEmail = authContext?.user.email.trim().toLowerCase();
    final currentUserEmployeeId = authContext?.user.employeeId;

    return employees.where((employee) {
      if (currentUserEmployeeId != null &&
          currentUserEmployeeId.isNotEmpty &&
          employee.id == currentUserEmployeeId) {
        return false;
      }

      if (currentUserEmail != null &&
          currentUserEmail.isNotEmpty &&
          employee.email.trim().toLowerCase() == currentUserEmail) {
        return false;
      }

      final matchesFilter = switch (filter) {
        EmployeeFilter.all => true,
        EmployeeFilter.active => employee.status == EmployeeStatus.active,
        EmployeeFilter.attention => needsAttention(employee),
        EmployeeFilter.inactive => employee.status == EmployeeStatus.inactive,
      };

      if (!matchesFilter) {
        return false;
      }

      if (normalizedQuery.isEmpty) {
        return true;
      }

      final haystack = <String>[
        employee.name,
        employee.role,
        employee.department,
        employee.email,
        employee.unit,
      ].join(' ').toLowerCase();

      return haystack.contains(normalizedQuery);
    }).toList()
      ..sort((left, right) {
        final leftPriority = needsAttention(left) ? 0 : 1;
        final rightPriority = needsAttention(right) ? 0 : 1;

        if (leftPriority != rightPriority) {
          return leftPriority.compareTo(rightPriority);
        }

        return left.name.compareTo(right.name);
      });
  }

  int get employeesTotal => visibleEmployees.length;

  int get employeesTotalPages {
    if (employeesTotal == 0) {
      return 1;
    }
    return (employeesTotal / employeesPageSize).ceil();
  }

  bool get employeesHasPrevious => employeesPage > 1;

  bool get employeesHasNext => employeesPage < employeesTotalPages;

  bool get hasEmployeesPagination => employeesTotalPages > 1;

  List<EmployeeProfile> get pagedEmployees {
    final visible = visibleEmployees;
    if (visible.isEmpty) {
      return <EmployeeProfile>[];
    }

    var startIndex = (employeesPage - 1) * employeesPageSize;
    if (startIndex < 0) {
      startIndex = 0;
    }
    if (startIndex > visible.length) {
      startIndex = visible.length;
    }

    var endIndex = startIndex + employeesPageSize;
    if (endIndex > visible.length) {
      endIndex = visible.length;
    }

    return visible.sublist(startIndex, endIndex);
  }

  EmployeeProfile? get selectedEmployee {
    final visible = visibleEmployees;
    if (visible.isEmpty) {
      return null;
    }

    for (final employee in visible) {
      if (employee.id == selectedEmployeeId) {
        return employee;
      }
    }

    return visible.first;
  }

  int get activeEmployees {
    return employees
        .where((employee) => employee.status == EmployeeStatus.active)
        .length;
  }

  int get attentionEmployees {
    return employees.where(needsAttention).length;
  }

  int get locationTrackedEmployees {
    return employees
        .where((employee) => employee.requiresLocationOnPunch)
        .length;
  }

  int get leadershipEmployees {
    return employees
        .where((employee) => employee.roleLevel == RoleLevel.leadership)
        .length;
  }

  bool needsAttention(EmployeeProfile employee) {
    return employee.pendingAdjustments > 0 ||
        employee.status == EmployeeStatus.onboarding ||
        employee.status == EmployeeStatus.onLeave ||
        employee.status == EmployeeStatus.inactive;
  }

  void setSearchQuery(String value) {
    searchQuery = value;
    employeesPage = 1;
    notifyListeners();
  }

  void clearSearch() {
    searchController.clear();
    searchQuery = '';
    employeesPage = 1;
    notifyListeners();
  }

  void setFilter(EmployeeFilter value) {
    filter = value;
    employeesPage = 1;
    notifyListeners();
  }

  void selectEmployee(String employeeId) {
    selectedEmployeeId = employeeId;
    employeePunchesPage = 1;
    notifyListeners();
  }

  void loadPreviousEmployeesPage() {
    if (!employeesHasPrevious) {
      return;
    }
    employeesPage -= 1;
    notifyListeners();
  }

  void loadNextEmployeesPage() {
    if (!employeesHasNext) {
      return;
    }
    employeesPage += 1;
    notifyListeners();
  }

  void _clampEmployeesPage() {
    if (employeesPage < 1) {
      employeesPage = 1;
      return;
    }

    final totalPages = employeesTotalPages;
    if (employeesPage > totalPages) {
      employeesPage = totalPages;
    }
  }

  Future<String?> createEmployee(EmployeeDraft draft) async {
    try {
      final employee = await _api.createEmployee(draft);
      employees = <EmployeeProfile>[employee, ...employees];
      selectedEmployeeId = employee.id;
      notifyListeners();
      await loadEmployeePunches(employee.id, page: 1);
      return '${employee.name} foi adicionado à empresa.';
    } on ApiException catch (error) {
      return error.message;
    }
  }

  Future<String?> updateEmployee(
    EmployeeProfile employee,
    EmployeeDraft draft,
  ) async {
    try {
      final updated = await _api.updateEmployee(employee.id, draft);
      employees = employees.map((currentEmployee) {
        if (currentEmployee.id != employee.id) {
          return currentEmployee;
        }

        return updated;
      }).toList();
      selectedEmployeeId = employee.id;
      notifyListeners();
      await loadEmployeePunches(employee.id, page: 1);
      return '${draft.name} foi atualizado com sucesso.';
    } on ApiException catch (error) {
      return error.message;
    }
  }

  Future<String?> deleteEmployee(EmployeeProfile employee) async {
    try {
      await _api.deleteEmployee(employee.id);
      employees = employees
          .where((currentEmployee) => currentEmployee.id != employee.id)
          .toList();
      _clampEmployeesPage();
      final fallbackSelection =
          visibleEmployees.isEmpty ? null : visibleEmployees.first.id;
      selectedEmployeeId = fallbackSelection;
      notifyListeners();
      if (fallbackSelection == null) {
        employeePunches = <ManagedPunchRecord>[];
        employeePunchesError = null;
        isLoadingEmployeePunches = false;
        employeePunchesPage = 1;
        employeePunchesTotal = 0;
        employeePunchesTotalPages = 1;
        employeePunchesHasPrevious = false;
        employeePunchesHasNext = false;
        notifyListeners();
      } else {
        await loadEmployeePunches(fallbackSelection, page: 1);
      }
      return '${employee.name} foi removido da empresa.';
    } on ApiException catch (error) {
      return error.message;
    }
  }

  Future<void> loadEmployeePunches(
    String employeeId, {
    int page = 1,
  }) async {
    isLoadingEmployeePunches = true;
    employeePunchesError = null;
    notifyListeners();

    try {
      final punchPage = await _api.listManagedPunches(
        employeeId,
        page: page,
        limit: employeePunchesPageSize,
      );
      if (selectedEmployeeId != employeeId) {
        return;
      }

      employeePunches = punchPage.records;
      employeePunchesPage = punchPage.recordsPage;
      employeePunchesPageSize = punchPage.recordsPageSize;
      employeePunchesTotal = punchPage.recordsTotal;
      employeePunchesTotalPages = punchPage.recordsTotalPages;
      employeePunchesHasPrevious = punchPage.recordsHasPrevious;
      employeePunchesHasNext = punchPage.recordsHasNext;
      isLoadingEmployeePunches = false;
      notifyListeners();
    } on ApiException catch (error) {
      if (selectedEmployeeId != employeeId) {
        return;
      }

      employeePunches = <ManagedPunchRecord>[];
      employeePunchesPage = 1;
      employeePunchesTotal = 0;
      employeePunchesTotalPages = 1;
      employeePunchesHasPrevious = false;
      employeePunchesHasNext = false;
      isLoadingEmployeePunches = false;
      employeePunchesError = error.message;
      notifyListeners();
    } catch (_) {
      if (selectedEmployeeId != employeeId) {
        return;
      }

      employeePunches = <ManagedPunchRecord>[];
      employeePunchesPage = 1;
      employeePunchesTotal = 0;
      employeePunchesTotalPages = 1;
      employeePunchesHasPrevious = false;
      employeePunchesHasNext = false;
      isLoadingEmployeePunches = false;
      employeePunchesError = 'Não foi possível carregar os pontos.';
      notifyListeners();
    }
  }

  Future<String?> createManagedPunch({
    required EmployeeProfile employee,
    required ManagedPunchDraft draft,
  }) async {
    try {
      await _api.createManagedPunch(employeeId: employee.id, draft: draft);
      await loadEmployeePunches(employee.id, page: 1);
      return 'Ponto manual de ${employee.name} foi criado.';
    } on ApiException catch (error) {
      return error.message;
    }
  }

  Future<String?> updateManagedPunch({
    required EmployeeProfile employee,
    required ManagedPunchRecord punch,
    required ManagedPunchDraft draft,
  }) async {
    try {
      await _api.updateManagedPunch(
        employeeId: employee.id,
        punchId: punch.id,
        draft: draft,
      );
      await loadEmployeePunches(employee.id, page: employeePunchesPage);
      return 'Ponto manual atualizado.';
    } on ApiException catch (error) {
      return error.message;
    }
  }

  Future<String?> deleteManagedPunch({
    required EmployeeProfile employee,
    required ManagedPunchRecord punch,
  }) async {
    try {
      await _api.deleteManagedPunch(
        employeeId: employee.id,
        punchId: punch.id,
      );
      await loadEmployeePunches(employee.id, page: employeePunchesPage);
      return 'Ponto manual removido.';
    } on ApiException catch (error) {
      return error.message;
    }
  }

  String filterLabel(EmployeeFilter value) {
    return switch (value) {
      EmployeeFilter.all => 'Todos',
      EmployeeFilter.active => 'Ativos',
      EmployeeFilter.attention => 'Atenção',
      EmployeeFilter.inactive => 'Inativos',
    };
  }

  String statusLabel(EmployeeStatus status) {
    return switch (status) {
      EmployeeStatus.active => 'Ativo',
      EmployeeStatus.onboarding => 'Onboarding',
      EmployeeStatus.onLeave => 'Afastado',
      EmployeeStatus.inactive => 'Inativo',
    };
  }

  String workModeLabel(EmployeeWorkMode workMode) {
    return switch (workMode) {
      EmployeeWorkMode.onsite => 'Presencial',
      EmployeeWorkMode.hybrid => 'Híbrido',
      EmployeeWorkMode.remote => 'Remoto',
    };
  }

  Color statusColor(EmployeeStatus status) {
    return switch (status) {
      EmployeeStatus.active => const Color(0xFF2F8F46),
      EmployeeStatus.onboarding => const Color(0xFF8C5D00),
      EmployeeStatus.onLeave => const Color(0xFF8C5D00),
      EmployeeStatus.inactive => const Color(0xFF8B1E1E),
    };
  }

  IconData statusIcon(EmployeeStatus status) {
    return switch (status) {
      EmployeeStatus.active => Icons.check_circle_rounded,
      EmployeeStatus.onboarding => Icons.rocket_launch_rounded,
      EmployeeStatus.onLeave => Icons.pause_circle_rounded,
      EmployeeStatus.inactive => Icons.do_not_disturb_on_rounded,
    };
  }

  IconData workModeSummaryIcon(EmployeeWorkMode workMode) {
    return switch (workMode) {
      EmployeeWorkMode.onsite => Icons.business_center_rounded,
      EmployeeWorkMode.hybrid => Icons.sync_alt_rounded,
      EmployeeWorkMode.remote => Icons.laptop_mac_rounded,
    };
  }

  String companyDisplayName(AuthCompanySummary? company) {
    if (company == null) {
      return 'Cadastro empresarial indisponível';
    }

    final tradeName = company.tradeName.trim();
    if (tradeName.isNotEmpty) {
      return tradeName;
    }

    return company.legalName.trim();
  }

  String companyIdentitySummary(AuthCompanySummary? company) {
    if (company == null) {
      return 'Não foi possível carregar os dados cadastrais da empresa.';
    }

    final legalName = company.legalName.trim();
    final displayName = companyDisplayName(company);

    if (legalName.isNotEmpty && legalName != displayName) {
      return legalName;
    }

    return 'Dados cadastrais confirmados.';
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
