import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/contracts/employee.dart';
import 'package:touchin_flutter/contracts/punch.dart';
import 'package:touchin_flutter/contracts/time_clock.dart';
import 'package:touchin_flutter/core/forms/br_input_masks.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/pagination_controls.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_shell.dart';
import 'package:touchin_flutter/features/admin/presentation/admin_employees_controller.dart';
import 'package:touchin_flutter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'admin_employees_page_widgets.dart';

class AdminEmployeesPage extends StatefulWidget {
  const AdminEmployeesPage({super.key, this.api, this.controller});

  final TouchInApi? api;
  final AdminEmployeesController? controller;

  @override
  State<AdminEmployeesPage> createState() => _AdminEmployeesPageState();
}

class _AdminEmployeesPageState extends State<AdminEmployeesPage> {
  late final AdminEmployeesController _controller;
  late final bool _ownsController;
  _EmployeeDetailTab _detailTab = _EmployeeDetailTab.registration;
  final GlobalKey _employeeDetailKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ?? AdminEmployeesController(api: widget.api);
    _ownsController = widget.controller == null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.start();
    });
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _openCreateEmployeeDialog() async {
    final draft = await showDialog<EmployeeDraft>(
      context: context,
      builder: (context) => const _EmployeeEditorDialog(),
    );

    if (draft == null || !mounted) {
      return;
    }

    final message = await _controller.createEmployee(draft);
    if (!mounted || message == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openEditEmployeeDialog(EmployeeProfile employee) async {
    final draft = await showDialog<EmployeeDraft>(
      context: context,
      builder: (context) => _EmployeeEditorDialog(employee: employee),
    );

    if (draft == null || !mounted) {
      return;
    }

    final message = await _controller.updateEmployee(employee, draft);
    if (!mounted || message == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _removeEmployee(EmployeeProfile employee) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          title: const Text('Remover funcionário'),
          content: Text(
            'Deseja remover ${employee.name}? Esta ação não pode ser desfeita.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remover'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final message = await _controller.deleteEmployee(employee);
    if (!mounted || message == null) {
      return;
    }

    messenger.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _selectEmployee(String employeeId, {required bool isWide}) {
    _controller.selectEmployee(employeeId);
    _controller.loadEmployeePunches(employeeId, page: 1);
    _scrollToEmployeeDetails(isWide: isWide);
  }

  Future<void> _loadEmployees() => _controller.loadEmployees();

  void _scrollToEmployeeDetails({required bool isWide}) {
    if (isWide) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || isWide) {
        return;
      }
      final detailContext = _employeeDetailKey.currentContext;
      if (detailContext == null) {
        return;
      }
      Scrollable.ensureVisible(
        detailContext,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        alignment: 0.04,
      );
    });
  }

  Future<void> _loadEmployeePunches({
    required String employeeId,
    int? page,
  }) {
    return _controller.loadEmployeePunches(
      employeeId,
      page: page ?? _controller.employeePunchesPage,
    );
  }

  Future<void> _openCreatePunchDialog(EmployeeProfile employee) async {
    final draft = await showDialog<ManagedPunchDraft>(
      context: context,
      builder: (context) => _ManagedPunchEditorDialog(employee: employee),
    );

    if (draft == null || !mounted) {
      return;
    }

    final message = await _controller.createManagedPunch(
      employee: employee,
      draft: draft,
    );
    if (!mounted || message == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openEditPunchDialog({
    required EmployeeProfile employee,
    required ManagedPunchRecord punch,
  }) async {
    final draft = await showDialog<ManagedPunchDraft>(
      context: context,
      builder: (context) => _ManagedPunchEditorDialog(
        employee: employee,
        punch: punch,
      ),
    );

    if (draft == null || !mounted) {
      return;
    }

    final message = await _controller.updateManagedPunch(
      employee: employee,
      punch: punch,
      draft: draft,
    );
    if (!mounted || message == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _deleteManagedPunch({
    required EmployeeProfile employee,
    required ManagedPunchRecord punch,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          title: const Text('Remover ponto'),
          content: Text(
            'Deseja remover o ponto de ${_formatDateTime(punch.timestamp)}? Esta ação não pode ser desfeita.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remover'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final message = await _controller.deleteManagedPunch(
      employee: employee,
      punch: punch,
    );
    if (!mounted || message == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  TextEditingController get _searchController => _controller.searchController;
  List<EmployeeProfile> get _employees => _controller.employees;
  AuthContext? get _authContext => _controller.authContext;
  EmployeeFilter get _filter => _controller.filter;
  String get _searchQuery => _controller.searchQuery;
  List<ManagedPunchRecord> get _employeePunches => _controller.employeePunches;
  bool get _isLoadingEmployeePunches => _controller.isLoadingEmployeePunches;
  String? get _employeePunchesError => _controller.employeePunchesError;
  bool get _isLoading => _controller.isLoading;
  String? get _loadError => _controller.loadError;
  EmployeeProfile? get _selectedEmployee => _controller.selectedEmployee;
  List<EmployeeProfile> get _visibleEmployees => _controller.visibleEmployees;
  List<EmployeeProfile> get _pagedEmployees => _controller.pagedEmployees;
  bool get _hasEmployeesPagination => _controller.hasEmployeesPagination;
  int get _employeesPage => _controller.employeesPage;
  int get _employeesTotalPages => _controller.employeesTotalPages;
  bool get _employeesHasPrevious => _controller.employeesHasPrevious;
  bool get _employeesHasNext => _controller.employeesHasNext;
  int get _activeEmployees => _controller.activeEmployees;
  int get _attentionEmployees => _controller.attentionEmployees;
  int get _locationTrackedEmployees => _controller.locationTrackedEmployees;
  int get _leadershipEmployees => _controller.leadershipEmployees;

  bool _needsAttention(EmployeeProfile employee) {
    return _controller.needsAttention(employee);
  }

  String _formatHours(int minutes) {
    final hours = (minutes ~/ 60).toString().padLeft(2, '0');
    final remainingMinutes = (minutes % 60).toString().padLeft(2, '0');
    return '${hours}h ${remainingMinutes}m';
  }

  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }

  Color _statusColor(EmployeeStatus status) {
    return _controller.statusColor(status);
  }

  String _statusLabel(EmployeeStatus status) {
    return _controller.statusLabel(status);
  }

  String _workModeLabel(EmployeeWorkMode workMode) {
    return _controller.workModeLabel(workMode);
  }

  IconData _statusIcon(EmployeeStatus status) {
    return _controller.statusIcon(status);
  }

  String _filterLabel(EmployeeFilter filter) {
    return _controller.filterLabel(filter);
  }

  String _companyDisplayName(AuthCompanySummary? company) {
    return _controller.companyDisplayName(company);
  }

  String _companyIdentitySummary(AuthCompanySummary? company) {
    return _controller.companyIdentitySummary(company);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return WorkspaceScaffold(
          sidebar: _buildSummaryPanel(),
          contentBuilder: (context, isWide) => _buildWorkspace(isWide: isWide),
        );
      },
    );
  }

  Widget _buildSummaryPanel() {
    final company = _authContext?.company;
    final companyName = _companyDisplayName(company);
    final companyIdentity = _companyIdentitySummary(company);

    return WorkspaceSidebar(
      title: 'Painel administrativo da empresa.',
      description:
          'Acompanhe equipe, pendências e regras operacionais em um só lugar.',
      summaryChildren: <Widget>[
        WorkspaceSummaryStripe(
          label: 'Empresa',
          value: companyName,
          helper: companyIdentity,
        ),
        WorkspaceSummaryStripe(
          label: 'Headcount',
          value: '${_employees.length} funcionários',
          helper: '$_activeEmployees ativos e $_leadershipEmployees lideranças',
        ),
        WorkspaceSummaryStripe(
          label: 'Pendências',
          value: '$_attentionEmployees em atenção',
          helper: 'Onboarding, afastamentos e ajustes',
        ),
      ],
      highlightChips: _buildSidebarHighlightChips(),
    );
  }

  List<Widget> _buildSidebarHighlightChips() {
    final workspaceAccessLabel =
        _authContext?.user.workspaceAccessLabel ?? 'Acesso autenticado';
    return <Widget>[
      WorkspaceHighlightChip(
        label: workspaceAccessLabel,
      ),
      const WorkspaceHighlightChip(label: 'Dados mascarados'),
    ];
  }

  Widget _buildWorkspace({required bool isWide}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isWide ? 32 : 24, 28, isWide ? 32 : 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildWorkspaceHeader(isWide),
          const SizedBox(height: 16),
          _buildMetricGrid(isWide),
          const SizedBox(height: 20),
          _buildEmployeesSection(isWide),
        ],
      ),
    );
  }

  Widget _buildWorkspaceHeader(bool isWide) {
    if (!isWide) {
      return WorkspaceHeader(
        title: 'Administrar equipe',
        description: '',
        maxContentWidth: 620,
        actions: _buildHeaderActions(false),
      );
    }

    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Text(
              'Administrar equipe',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ..._buildHeaderActions(true),
      ],
    );
  }

  List<Widget> _buildHeaderActions(bool isWide) {
    final createButton = SizedBox(
      width: isWide ? 210 : double.infinity,
      child: ElevatedButton.icon(
        onPressed: _openCreateEmployeeDialog,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Novo funcionário'),
      ),
    );

    return <Widget>[createButton];
  }

  Widget _buildMetricGrid(bool isWide) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useSingleRow = isWide && constraints.maxWidth >= 980;
        final useTwoColumns = !useSingleRow && constraints.maxWidth >= 500;
        final itemWidth = useTwoColumns
            ? (constraints.maxWidth - 8) / 2
            : constraints.maxWidth;
        final metricItems = <Widget>[
          _AdminMetricItem(
            icon: Icons.groups_2_rounded,
            label: 'Colaboradores',
            value: _employees.length.toString(),
          ),
          _AdminMetricItem(
            icon: Icons.verified_user_rounded,
            label: 'Ativos',
            value: _activeEmployees.toString(),
          ),
          _AdminMetricItem(
            icon: Icons.location_on_rounded,
            label: 'Com geolocalização',
            value: _locationTrackedEmployees.toString(),
          ),
          _AdminMetricItem(
            icon: Icons.warning_amber_rounded,
            label: 'Em atenção',
            value: _attentionEmployees.toString(),
          ),
        ];

        return useSingleRow
            ? Row(
                children: metricItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: index == metricItems.length - 1 ? 0 : 8,
                      ),
                      child: item,
                    ),
                  );
                }).toList(),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: metricItems
                    .map(
                      (item) => SizedBox(
                        width: itemWidth,
                        child: item,
                      ),
                    )
                    .toList(),
              );
      },
    );
  }

  Widget _buildEmployeesSection(bool isWide) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useSplitLayout = isWide && constraints.maxWidth >= 980;

        if (useSplitLayout) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                  flex: 11, child: _buildEmployeesListCard(isWide: isWide)),
              const SizedBox(width: 20),
              Expanded(flex: 9, child: _buildEmployeeDetailCard()),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildEmployeesListCard(isWide: isWide),
            const SizedBox(height: 20),
            _buildEmployeeDetailCard(),
          ],
        );
      },
    );
  }

  Widget _buildEmployeesListCard({required bool isWide}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visibleEmployees = _visibleEmployees;
    final pagedEmployees = _pagedEmployees;

    return WorkspaceSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Equipe',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Busque e selecione perfis para editar dados principais.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _searchController,
            onChanged: (value) {
              _controller.setSearchQuery(value);
            },
            decoration: InputDecoration(
              labelText: 'Buscar funcionário',
              hintText: 'Nome, cargo ou unidade',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _controller.clearSearch();
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: EmployeeFilter.values.map((filter) {
              return ChoiceChip(
                label: Text(_filterLabel(filter)),
                selected: _filter == filter,
                checkmarkColor: AppTheme.accent,
                onSelected: (_) {
                  _controller.setFilter(filter);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_loadError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.8),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _loadError!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _loadEmployees,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Tentar novamente'),
                  ),
                ],
              ),
            )
          else if (visibleEmployees.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.8),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Nenhum funcionário encontrado.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ajuste os filtros ou cadastre um novo colaborador para continuar.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _openCreateEmployeeDialog,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Novo funcionário'),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                ...pagedEmployees.map((employee) {
                  final selected = employee.id == _selectedEmployee?.id;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _EmployeeListTile(
                      employee: employee,
                      selected: selected,
                      statusColor: _statusColor(employee.status),
                      statusIcon: _statusIcon(employee.status),
                      statusLabel: _statusLabel(employee.status),
                      needsAttention: _needsAttention(employee),
                      onTap: () => _selectEmployee(employee.id, isWide: isWide),
                      onEdit: () => _openEditEmployeeDialog(employee),
                      onDelete: () => _removeEmployee(employee),
                    ),
                  );
                }),
                if (_hasEmployeesPagination) ...[
                  const SizedBox(height: 16),
                  PaginationControls(
                    page: _employeesPage,
                    totalPages: _employeesTotalPages,
                    hasPrevious: _employeesHasPrevious,
                    hasNext: _employeesHasNext,
                    onPrevious: _controller.loadPreviousEmployeesPage,
                    onNext: _controller.loadNextEmployeesPage,
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _wrapEmployeeDetailCard({required Widget child}) {
    return KeyedSubtree(
      key: _employeeDetailKey,
      child: child,
    );
  }

  Widget _buildEmployeeDetailCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final employee = _selectedEmployee;

    if (employee == null) {
      return _wrapEmployeeDetailCard(
        child: WorkspaceSectionCard(
          child: Row(
            children: <Widget>[
              Icon(
                Icons.touch_app_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Selecione um funcionário para ver os detalhes.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final hasNotes = employee.notes.trim().isNotEmpty;
    final lastPunchLabel = employee.lastPunchAt == null
        ? 'Sem registro'
        : _formatDateTime(employee.lastPunchAt!);

    return _wrapEmployeeDetailCard(
      child: WorkspaceSectionCard(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final useTwoColumns = constraints.maxWidth >= 520;
            final overviewItemWidth = useTwoColumns
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            final activeTab = hasNotes || _detailTab != _EmployeeDetailTab.notes
                ? _detailTab
                : _EmployeeDetailTab.registration;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _EmployeeDetailHero(
                  employee: employee,
                  statusLabel: _statusLabel(employee.status),
                  statusColor: _statusColor(employee.status),
                  statusIcon: _statusIcon(employee.status),
                  workModeLabel: _workModeLabel(employee.workMode),
                  workModeIcon: _workModeSummaryIcon(employee.workMode),
                  needsAttention: _needsAttention(employee),
                  onEdit: () => _openEditEmployeeDialog(employee),
                ),
                const SizedBox(height: 12),
                Text(
                  'Resumo rápido',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    SizedBox(
                      width: overviewItemWidth,
                      child: _EmployeeOverviewCard(
                        icon: Icons.schedule_rounded,
                        label: 'Jornada',
                        value: employee.expectedShiftLabel,
                      ),
                    ),
                    SizedBox(
                      width: overviewItemWidth,
                      child: _EmployeeOverviewCard(
                        icon: Icons.av_timer_rounded,
                        label: 'Horas de hoje',
                        value: _formatHours(employee.todayWorkedMinutes),
                      ),
                    ),
                    SizedBox(
                      width: overviewItemWidth,
                      child: _EmployeeOverviewCard(
                        icon: Icons.history_toggle_off_rounded,
                        label: 'Última batida',
                        value: lastPunchLabel,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDetailTabSelector(
                  activeTab: activeTab,
                  hasNotes: hasNotes,
                  useVerticalLayout: constraints.maxWidth < 360,
                ),
                const SizedBox(height: 12),
                if (activeTab == _EmployeeDetailTab.registration)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: 0.82),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Column(
                      children: <Widget>[
                        _EmployeeDetailRow(
                          icon: Icons.alternate_email_rounded,
                          label: 'E-mail',
                          value: employee.email,
                        ),
                        Divider(color: colorScheme.outlineVariant, height: 1),
                        _EmployeeDetailRow(
                          icon: Icons.phone_outlined,
                          label: 'Telefone',
                          value: employee.phone,
                        ),
                      ],
                    ),
                  )
                else if (activeTab == _EmployeeDetailTab.policies)
                  Column(
                    children: <Widget>[
                      _EmployeePolicyRow(
                        icon: Icons.location_searching_rounded,
                        title: 'Validação de localização',
                        value: employee.requiresLocationOnPunch
                            ? 'Obrigatória nas batidas'
                            : 'Flexível para a operação',
                        tone: employee.requiresLocationOnPunch
                            ? const Color(0xFF1F4E79)
                            : const Color(0xFF6B6254),
                      ),
                      const SizedBox(height: 10),
                      _EmployeePolicyRow(
                        icon: Icons.verified_user_outlined,
                        title: 'Dispositivo confiável',
                        value: employee.trustedDeviceRequired
                            ? 'Exigido para registrar ponto'
                            : 'Sem restrição ativa',
                        tone: employee.trustedDeviceRequired
                            ? const Color(0xFF2F8F46)
                            : const Color(0xFF6B6254),
                      ),
                      const SizedBox(height: 10),
                      _EmployeePolicyRow(
                        icon: employee.pendingAdjustments > 0
                            ? Icons.warning_amber_rounded
                            : Icons.task_alt_rounded,
                        title: 'Ajustes pendentes',
                        value: employee.pendingAdjustments > 0
                            ? '${employee.pendingAdjustments} aguardando revisão'
                            : 'Nenhum ajuste em aberto',
                        tone: employee.pendingAdjustments > 0
                            ? const Color(0xFF8C5D00)
                            : const Color(0xFF2F8F46),
                      ),
                    ],
                  )
                else if (activeTab == _EmployeeDetailTab.timeClock)
                  _buildPunchManagementSection(
                    employee: employee,
                    constraints: constraints,
                  )
                else
                  _EmployeeNarrativeCard(
                    icon: Icons.sticky_note_2_outlined,
                    label: 'Notas da gestão',
                    value: employee.notes,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPunchManagementSection({
    required EmployeeProfile employee,
    required BoxConstraints constraints,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCompact = constraints.maxWidth < 540;
    final totalPages = _controller.employeePunchesTotalPages;
    final currentPage = _controller.employeePunchesPage;
    final visiblePunches = _employeePunches;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.82),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Gestão de ponto',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Crie ou ajuste batidas manuais sem misturar isso com navegação.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                        if (_controller.employeePunchesTotal > 0) ...<Widget>[
                          const SizedBox(height: 6),
                          Text(
                            '${_controller.employeePunchesTotal} registros',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!isCompact) ...<Widget>[
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _openCreatePunchDialog(employee),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('Novo ponto'),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Atualizar',
                      child: IconButton.filledTonal(
                        onPressed: () =>
                            _loadEmployeePunches(employeeId: employee.id),
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ),
                  ],
                ],
              ),
              if (isCompact) ...<Widget>[
                const SizedBox(height: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ElevatedButton.icon(
                      onPressed: () => _openCreatePunchDialog(employee),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('Novo ponto'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _loadEmployeePunches(employeeId: employee.id),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Atualizar'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoadingEmployeePunches)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_employeePunchesError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.8),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _employeePunchesError!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () =>
                      _loadEmployeePunches(employeeId: employee.id),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          )
        else if (_employeePunches.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.8),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Nenhum ponto manual registrado.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use a criação manual para corrigir batidas, ajustar horários ou registrar eventos passados.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => _openCreatePunchDialog(employee),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('Novo ponto'),
                ),
              ],
            ),
          )
        else
          Column(
            children: <Widget>[
              ...visiblePunches.map((punch) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ManagedPunchTile(
                    punch: punch,
                    onEdit: () => _openEditPunchDialog(
                      employee: employee,
                      punch: punch,
                    ),
                    onDelete: () => _deleteManagedPunch(
                      employee: employee,
                      punch: punch,
                    ),
                  ),
                );
              }),
              if (totalPages > 1) ...<Widget>[
                const SizedBox(height: 8),
                PaginationControls(
                  page: currentPage,
                  totalPages: totalPages,
                  hasPrevious: _controller.employeePunchesHasPrevious,
                  hasNext: _controller.employeePunchesHasNext,
                  onPrevious: () {
                    final previousPage = currentPage - 1;
                    _controller.loadEmployeePunches(
                      employee.id,
                      page: previousPage,
                    );
                  },
                  onNext: () {
                    final nextPage = currentPage + 1;
                    _controller.loadEmployeePunches(
                      employee.id,
                      page: nextPage,
                    );
                  },
                ),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildDetailTabSelector({
    required _EmployeeDetailTab activeTab,
    required bool hasNotes,
    required bool useVerticalLayout,
  }) {
    const tabItems = <({
      _EmployeeDetailTab value,
      IconData icon,
      String label,
    })>[
      (
        value: _EmployeeDetailTab.registration,
        icon: Icons.badge_outlined,
        label: 'Cadastro',
      ),
      (
        value: _EmployeeDetailTab.policies,
        icon: Icons.policy_outlined,
        label: 'Políticas',
      ),
      (
        value: _EmployeeDetailTab.timeClock,
        icon: Icons.schedule_rounded,
        label: 'Ponto',
      ),
      (
        value: _EmployeeDetailTab.notes,
        icon: Icons.notes_rounded,
        label: 'Notas',
      ),
    ];
    final colorScheme = Theme.of(context).colorScheme;
    final visibleItems = tabItems
        .where((item) => hasNotes || item.value != _EmployeeDetailTab.notes)
        .toList();
    final selectedTab = visibleItems.any((item) => item.value == activeTab)
        ? activeTab
        : visibleItems.first.value;
    final selectedTabForeground =
        ThemeData.estimateBrightnessForColor(AppTheme.accent) == Brightness.dark
            ? Colors.white
            : Colors.black87;

    Widget buildTabButton({
      required _EmployeeDetailTab value,
      required IconData icon,
      required String label,
    }) {
      final selected = value == selectedTab;
      return OutlinedButton.icon(
        onPressed: () {
          if (selected) {
            return;
          }
          setState(() {
            _detailTab = value;
          });
        },
        style: ButtonStyle(
          animationDuration: Duration.zero,
          minimumSize: MaterialStateProperty.all(const Size.fromHeight(48)),
          backgroundColor: MaterialStateProperty.resolveWith((_) {
            return selected ? AppTheme.accent : Colors.transparent;
          }),
          foregroundColor: MaterialStateProperty.resolveWith((_) {
            return selected ? selectedTabForeground : colorScheme.onSurface;
          }),
          side: MaterialStateProperty.all(
            const BorderSide(color: AppTheme.accent),
          ),
          shape: MaterialStateProperty.all(
            const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
        ),
        icon: Icon(icon),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    if (!useVerticalLayout) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth =
              (constraints.maxWidth - (visibleItems.length > 1 ? 8 : 0)) / 2;

          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: visibleItems.map((item) {
              return SizedBox(
                width: itemWidth,
                child: buildTabButton(
                  value: item.value,
                  icon: item.icon,
                  label: item.label,
                ),
              );
            }).toList(),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: visibleItems.map((item) {
        return Padding(
          padding: EdgeInsets.only(bottom: item == visibleItems.last ? 0 : 8),
          child: buildTabButton(
            value: item.value,
            icon: item.icon,
            label: item.label,
          ),
        );
      }).toList(),
    );
  }

  IconData _workModeSummaryIcon(EmployeeWorkMode workMode) {
    return _controller.workModeSummaryIcon(workMode);
  }
}

enum _EmployeeDetailTab { registration, policies, timeClock, notes }
