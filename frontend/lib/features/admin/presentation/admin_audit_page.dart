import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:touchin_flutter/contracts/audit.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/core/platform/file_download.dart';
import 'package:touchin_flutter/features/admin/presentation/admin_audit_page_widgets.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_shell.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_skeleton.dart';
import 'package:touchin_flutter/theme/app_theme.dart';

typedef _AuditFilters = ({
  DateTime? startDate,
  DateTime? endDate,
  String? actorUserId,
  String? action,
  String? entityType,
  String? entityId,
  String? projectId,
  String? result,
});

class AdminAuditPage extends StatefulWidget {
  const AdminAuditPage({super.key, this.api, this.saveAuditExport});

  final TouchInApi? api;
  final Future<void> Function(String filename, Uint8List bytes)?
      saveAuditExport;

  @override
  State<AdminAuditPage> createState() => _AdminAuditPageState();
}

class _AdminAuditPageState extends State<AdminAuditPage> {
  static const _AuditFilters _noFilters = (
    startDate: null,
    endDate: null,
    actorUserId: null,
    action: null,
    entityType: null,
    entityId: null,
    projectId: null,
    result: null,
  );
  static const _actionLabels = {
    'project.created': 'Projeto criado',
    'project.updated': 'Projeto atualizado',
    'project.deleted': 'Projeto excluído',
    'project.member_added': 'Membro adicionado ao projeto',
    'project.member_removed': 'Membro removido do projeto',
    'card.created': 'Tarefa criada',
    'card.updated': 'Tarefa atualizada',
    'card.deleted': 'Tarefa excluída',
    'card.assignee_added': 'Responsável adicionado à tarefa',
    'card.assignee_removed': 'Responsável removido da tarefa',
    'card.reordered': 'Tarefa reordenada',
    'card.moved': 'Tarefa movida',
    'employee.created': 'Funcionário criado',
    'employee.updated': 'Funcionário atualizado',
    'employee.deleted': 'Funcionário excluído',
    'task.created': 'Tarefa criada',
    'task.updated': 'Tarefa atualizada',
    'task.deleted': 'Tarefa excluída',
    'task.assignee_added': 'Responsável adicionado à tarefa',
    'task.assignee_removed': 'Responsável removido da tarefa',
    'task.reordered': 'Tarefa reordenada',
    'kanban.column_created': 'Coluna criada',
    'kanban.column_updated': 'Coluna atualizada',
    'kanban.column_reordered': 'Coluna reordenada',
    'kanban.column_deleted': 'Coluna excluída',
  };
  static const _resultLabels = {
    'success': 'Sucesso',
    'failed': 'Falha',
  };

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isExporting = false;
  bool _exportFailed = false;
  bool _exportHadData = false;
  String? _exportStatus;
  String? _error;
  bool _filterPanelOpen = false;
  VoidCallback? _refreshFilterSheet;
  final List<AuditEventResponse> _events = [];
  bool _hasMore = true;
  int _requestGeneration = 0;
  late final TouchInApi _api;

  int _page = 1;
  final int _limit = 50;

  final ScrollController _scrollController = ScrollController();
  final ScrollController _headerScrollController = ScrollController();
  final FocusNode _loadMoreFocusNode = FocusNode();
  final FocusNode _endOfResultsFocusNode = FocusNode();

  DateTime? _startDate;
  DateTime? _endDate;
  final _actorUserIdController = TextEditingController();
  final _actionController = TextEditingController();
  final _entityTypeController = TextEditingController();
  final _entityIdController = TextEditingController();
  final _projectIdController = TextEditingController();
  final _resultController = TextEditingController();

  _AuditFilters _appliedFilters = _noFilters;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? TouchInApi();
    _scrollController.addListener(_onScroll);
    _loadEvents(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _headerScrollController.dispose();
    _loadMoreFocusNode.dispose();
    _endOfResultsFocusNode.dispose();
    _actorUserIdController.dispose();
    _actionController.dispose();
    _entityTypeController.dispose();
    _entityIdController.dispose();
    _projectIdController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isLoadingMore && _hasMore && _error == null) {
        _loadEvents();
      }
    }
  }

  _AuditFilters _draftFilters() {
    String? trimmed(TextEditingController controller) {
      final value = controller.text.trim();
      return value.isEmpty ? null : value;
    }

    return (
      startDate: _startDate,
      endDate: _endDate,
      actorUserId: trimmed(_actorUserIdController),
      action: trimmed(_actionController),
      entityType: trimmed(_entityTypeController),
      entityId: trimmed(_entityIdController),
      projectId: trimmed(_projectIdController),
      result: trimmed(_resultController),
    );
  }

  bool get _hasPendingFilterChanges => _draftFilters() != _appliedFilters;

  int get _appliedFilterCount {
    final filters = _appliedFilters;
    return [
      filters.startDate != null || filters.endDate != null,
      filters.actorUserId != null,
      filters.action != null,
      filters.entityType != null,
      filters.entityId != null,
      filters.projectId != null,
      filters.result != null,
    ].where((active) => active).length;
  }

  String get _filterButtonLabel {
    if (_appliedFilterCount == 0) return 'Filtros';
    return 'Filtros ($_appliedFilterCount)';
  }

  Future<void> _loadEvents({bool refresh = false, bool retry = false}) async {
    if (!refresh &&
        (_isLoading ||
            _isLoadingMore ||
            !_hasMore ||
            (_error != null && !retry))) {
      return;
    }
    if (refresh) _requestGeneration++;
    final generation = _requestGeneration;
    final requestedPage = refresh ? 1 : _page;
    final filters = _appliedFilters;
    try {
      if (refresh) {
        setState(() {
          _isLoading = true;
          _isLoadingMore = false;
          _error = null;
          _page = 1;
          _events.clear();
          _hasMore = true;
        });
      } else {
        setState(() {
          _isLoadingMore = true;
          _error = null;
        });
      }

      final newEvents = await _api.listAuditEvents(
        page: requestedPage,
        limit: _limit,
        startDate: filters.startDate,
        endDate: filters.endDate,
        actorUserId: filters.actorUserId,
        action: filters.action,
        entityType: filters.entityType,
        entityId: filters.entityId,
        projectId: filters.projectId,
        result: filters.result,
      );

      if (!mounted || generation != _requestGeneration) return;
      final moveFocusToEnd =
          !refresh && _loadMoreFocusNode.hasFocus && newEvents.length < _limit;
      setState(() {
        if (newEvents.length < _limit) {
          _hasMore = false;
        }
        _events.addAll(newEvents);
        _page = requestedPage + 1;
        _isLoading = false;
        _isLoadingMore = false;
      });
      if (refresh) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        });
      }
      if (moveFocusToEnd) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_hasMore) _endOfResultsFocusNode.requestFocus();
        });
      }
    } catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _error = _errorMessage(e);
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  String _errorMessage(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 403) {
        return 'Você não tem permissão para consultar a auditoria.';
      }
      if (error.statusCode == 404) {
        return 'O serviço de auditoria não foi encontrado.';
      }
      if (error.statusCode != null && error.statusCode! >= 500) {
        return 'Serviço temporariamente indisponível. Tente novamente.';
      }
      if (error.message.startsWith('Contrato invalido')) {
        return 'O serviço de auditoria retornou uma resposta inválida.';
      }
      return error.message;
    }
    return 'Não foi possível carregar os eventos de auditoria. Tente novamente.';
  }

  String _exportErrorMessage(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 403) {
        return 'Você não tem permissão para exportar a auditoria.';
      }
      if (error.statusCode != null && error.statusCode! >= 500) {
        return 'Serviço temporariamente indisponível. Tente novamente.';
      }
      return error.message;
    }
    return 'Não foi possível exportar os registros. Tente novamente.';
  }

  Future<void> _exportEvents() async {
    if (_isExporting) return;
    final filters = _appliedFilters;
    setState(() {
      _isExporting = true;
      _exportFailed = false;
      _exportHadData = false;
      _exportStatus = 'Exportando registros...';
    });

    try {
      final export = await _api.exportAuditEvents(
        startDate: filters.startDate,
        endDate: filters.endDate,
        actorUserId: filters.actorUserId,
        action: filters.action,
        entityType: filters.entityType,
        entityId: filters.entityId,
        projectId: filters.projectId,
        result: filters.result,
      );
      if (!mounted) return;

      final scopeChanged = _appliedFilters != filters;
      if (export.rowCount == 0) {
        setState(() {
          _isExporting = false;
          _exportFailed = false;
          _exportHadData = false;
          _exportStatus = scopeChanged
              ? null
              : 'Nenhum registro corresponde aos filtros aplicados.';
        });
        return;
      }

      final save = widget.saveAuditExport ??
          (String filename, Uint8List bytes) =>
              downloadFileBytes(filename: filename, bytes: bytes);
      await save(export.filename, export.bytes);
      if (!mounted) return;

      if (_appliedFilters != filters) {
        setState(() {
          _isExporting = false;
          _exportFailed = false;
          _exportHadData = false;
          _exportStatus = null;
        });
        return;
      }

      final count = export.rowCount;
      setState(() {
        _isExporting = false;
        _exportFailed = false;
        _exportHadData = true;
        _exportStatus = count == null
            ? 'Exportação concluída. Timestamps em UTC.'
            : 'Exportação concluída: $count '
                '${count == 1 ? 'registro' : 'registros'} em UTC.';
      });
    } on UnsupportedError {
      if (!mounted) return;
      final scopeChanged = _appliedFilters != filters;
      setState(() {
        _isExporting = false;
        _exportFailed = !scopeChanged;
        _exportHadData = false;
        _exportStatus = scopeChanged
            ? null
            : 'O download de arquivos está disponível apenas na versão web.';
      });
    } catch (error) {
      if (!mounted) return;
      final scopeChanged = _appliedFilters != filters;
      setState(() {
        _isExporting = false;
        _exportFailed = !scopeChanged;
        _exportHadData = false;
        _exportStatus = scopeChanged ? null : _exportErrorMessage(error);
      });
    }
  }

  String _eventActionLabel(String value) =>
      _actionLabels[value] ?? 'Ação desconhecida ($value)';

  String _eventResultLabel(String value) =>
      _resultLabels[value] ?? 'Resultado desconhecido ($value)';

  Future<void> _pickDate(bool isStart) async {
    final initialDate =
        isStart ? _startDate ?? DateTime.now() : _endDate ?? DateTime.now();
    final baseTheme = Theme.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: AppTheme.adminContrastTheme(baseTheme),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
      _exportStatus = null;
      _exportFailed = false;
    });
    _refreshFilterSheet?.call();
  }

  void _scrollHeaderToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _headerScrollController.hasClients) {
        _headerScrollController.jumpTo(0);
      }
    });
  }

  void _onDraftChanged(String _) {
    if (!mounted) return;
    setState(() {
      if (!_isExporting) {
        _exportStatus = null;
        _exportFailed = false;
      }
    });
  }

  void _setDraftFromFilters(_AuditFilters filters) {
    _actorUserIdController.text = filters.actorUserId ?? '';
    _actionController.text = filters.action ?? '';
    _entityTypeController.text = filters.entityType ?? '';
    _entityIdController.text = filters.entityId ?? '';
    _projectIdController.text = filters.projectId ?? '';
    _resultController.text = filters.result ?? '';
    _startDate = filters.startDate;
    _endDate = filters.endDate;
  }

  void _applyFilters() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _appliedFilters = _draftFilters();
      _filterPanelOpen = false;
      _exportStatus = null;
      _exportFailed = false;
    });
    _scrollHeaderToTop();
    _loadEvents(refresh: true);
  }

  void _clearFilters() {
    _actorUserIdController.clear();
    _actionController.clear();
    _entityTypeController.clear();
    _entityIdController.clear();
    _projectIdController.clear();
    _resultController.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _startDate = null;
      _endDate = null;
      _appliedFilters = _noFilters;
      _filterPanelOpen = false;
      _exportStatus = null;
      _exportFailed = false;
    });
    _scrollHeaderToTop();
    _loadEvents(refresh: true);
  }

  void _discardDraftChanges() {
    setState(() {
      _setDraftFromFilters(_appliedFilters);
      _filterPanelOpen = false;
      _exportStatus = null;
      _exportFailed = false;
    });
    _scrollHeaderToTop();
  }

  void _toggleDesktopFilters() {
    final opening = !_filterPanelOpen;
    setState(() {
      _filterPanelOpen = opening;
    });
    if (opening) _scrollHeaderToTop();
  }

  Future<void> _openMobileFilters() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            _refreshFilterSheet = () {
              if (sheetContext.mounted) setSheetState(() {});
            };
            return Theme(
              data: AppTheme.adminContrastTheme(Theme.of(context)),
              child: _buildMobileFilterSheet(sheetContext),
            );
          },
        );
      },
    );
    _refreshFilterSheet = null;
    if (!mounted) return;
    setState(() {
      _setDraftFromFilters(_appliedFilters);
    });
  }

  void _openFilters(bool compact) {
    if (compact) {
      _openMobileFilters();
    } else {
      _toggleDesktopFilters();
    }
  }

  void _openEventDetails(AuditEventResponse event) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Theme(
        data: AppTheme.adminContrastTheme(Theme.of(context)),
        child: AuditEventDetailsDialog(
          event: event,
          actionLabel: _eventActionLabel(event.action),
          resultLabel: _eventResultLabel(event.result),
          onClose: () => Navigator.of(dialogContext).pop(),
        ),
      ),
    );
  }

  List<Widget> _activeFilterChips() {
    final filters = _appliedFilters;
    final chips = <Widget>[];
    final period = _periodLabel(filters.startDate, filters.endDate);
    if (period != null) {
      chips.add(_filterChip(Icons.date_range_outlined, 'Período: $period'));
    }
    if (filters.actorUserId != null) {
      chips.add(
        _filterChip(
            Icons.person_outline_rounded, 'Ator: ${filters.actorUserId}'),
      );
    }
    if (filters.action != null) {
      chips.add(_filterChip(Icons.bolt_outlined, 'Ação: ${filters.action}'));
    }
    if (filters.entityType != null) {
      chips.add(
        _filterChip(
          Icons.inventory_2_outlined,
          'Tipo: ${auditEntityLabel(filters.entityType!)}',
        ),
      );
    }
    if (filters.entityId != null) {
      chips.add(
        _filterChip(Icons.tag_rounded, 'Entidade: ${filters.entityId}'),
      );
    }
    if (filters.projectId != null) {
      chips.add(
        _filterChip(Icons.folder_outlined, 'Projeto: ${filters.projectId}'),
      );
    }
    if (filters.result != null) {
      chips.add(
        _filterChip(
          Icons.check_circle_outline_rounded,
          'Resultado: ${_eventResultLabel(filters.result!)}',
        ),
      );
    }
    return chips;
  }

  Widget _filterChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 15),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }

  String? _periodLabel(DateTime? start, DateTime? end) {
    String date(DateTime value) => '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/${value.year}';
    if (start != null && end != null) {
      return '${date(start)} a ${date(end)}';
    }
    if (start != null) return 'a partir de ${date(start)}';
    if (end != null) return 'até ${date(end)}';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.adminContrastTheme(Theme.of(context)),
      child: _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
    return WorkspaceScaffold(
      contextualContent: const WorkspaceSidebar(
        summaryChildren: [],
        highlightChips: [],
      ),
      contentScrollable: false,
      contentBuilder: (context, isWide) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 860 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3;
          final maxHeaderHeight =
              MediaQuery.sizeOf(context).height * (compact ? 0.58 : 0.64);
          return Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeaderHeight),
                child: SingleChildScrollView(
                  key: const ValueKey<String>('audit-header-scroll'),
                  controller: _headerScrollController,
                  padding: EdgeInsets.fromLTRB(
                    compact ? 16 : 24,
                    18,
                    compact ? 16 : 24,
                    8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(compact: compact),
                      const SizedBox(height: 14),
                      _buildActiveFilters(),
                      if (_filterPanelOpen && !compact) ...[
                        const SizedBox(height: 12),
                        _buildDesktopFilterPanel(),
                      ],
                      if (_isExporting || _exportStatus != null) ...[
                        const SizedBox(height: 10),
                        _buildExportFeedback(),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(child: _buildResults(compact: compact)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader({required bool compact}) {
    final actions = <Widget>[
      OutlinedButton.icon(
        key: const ValueKey<String>('audit-filters-button'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        onPressed: () => _openFilters(compact),
        icon: const Icon(Icons.tune_rounded, size: 18),
        label: Text(_filterButtonLabel),
      ),
      FilledButton.icon(
        key: const ValueKey<String>('audit-export-button'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onPressed: _isExporting ? null : _exportEvents,
        icon: _isExporting
            ? const SizedBox.shrink()
            : const Icon(Icons.download_rounded, size: 18),
        label: Text(_isExporting ? 'Exportando...' : 'Exportar CSV'),
      ),
    ];

    return WorkspaceHeader(
      title: 'Eventos de auditoria',
      description: compact
          ? 'Consulte e exporte os eventos registrados da empresa.'
          : 'Consulte, compare e exporte os eventos registrados para a sua empresa.',
      maxContentWidth: 570,
      actions: actions,
      compact: compact,
    );
  }

  Widget _buildActiveFilters() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final adminColors = AppTheme.adminColors(theme);
    final chips = _activeFilterChips();

    return Container(
      key: const ValueKey<String>('audit-active-filters'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.filter_alt_outlined,
                size: 17,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Filtros aplicados',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (chips.isNotEmpty)
                TextButton(
                  key: const ValueKey<String>('audit-clear-filters'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: _clearFilters,
                  child: const Text('Limpar filtros'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (chips.isEmpty)
            Text(
              'Nenhum filtro aplicado — todos os eventos da empresa.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(spacing: 8, runSpacing: 6, children: chips),
          if (_hasPendingFilterChanges) ...[
            const SizedBox(height: 9),
            Container(
              key: const ValueKey<String>('audit-pending-filters'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: adminColors.info.container,
                border: Border.all(
                  color: adminColors.info.foreground.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 17,
                    color: adminColors.info.foreground,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Alterações nos filtros ainda não aplicadas. A lista e o CSV usam os filtros aplicados.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: adminColors.info.foreground,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            key: const ValueKey<String>('audit-export-scope'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.file_download_outlined,
                size: 15,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'CSV com todos os registros dos filtros aplicados • timestamps em UTC.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopFilterPanel() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      key: const ValueKey<String>('audit-filter-panel'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Filtros da auditoria',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _filterPanelOpen = false),
                tooltip: 'Fechar filtros',
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildFilterFields(compact: false),
        ],
      ),
    );
  }

  Widget _buildMobileFilterSheet(BuildContext sheetContext) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Material(
        key: const ValueKey<String>('audit-filter-sheet'),
        color: colorScheme.surface,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filtros da auditoria',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    tooltip: 'Fechar filtros',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Divider(color: colorScheme.outlineVariant),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: _buildFilterFields(
                  compact: true,
                  sheetContext: sheetContext,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterFields({
    required bool compact,
    BuildContext? sheetContext,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720
            ? 3
            : constraints.maxWidth >= 480
                ? 2
                : 1;
        const spacing = 10.0;
        final fieldWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        Widget field(String label, TextEditingController controller,
            {String? hint}) {
          return SizedBox(
            width: fieldWidth,
            child: TextField(
              controller: controller,
              onChanged: _onDraftChanged,
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                isDense: true,
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                field('ID do usuário (ator)', _actorUserIdController,
                    hint: 'ID técnico do ator'),
                field('Ação', _actionController, hint: 'card.moved'),
                field('Tipo de entidade', _entityTypeController,
                    hint: 'card, project ou employee'),
                field('ID da entidade', _entityIdController),
                field('ID do projeto', _projectIdController),
                field('Resultado', _resultController,
                    hint: 'success ou failed'),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey<String>('audit-start-date'),
                  onPressed: () => _pickDate(true),
                  icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: Text(
                    _startDate == null
                        ? 'Data inicial'
                        : auditLocalDate(_startDate!),
                  ),
                ),
                OutlinedButton.icon(
                  key: const ValueKey<String>('audit-end-date'),
                  onPressed: () => _pickDate(false),
                  icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: Text(
                    _endDate == null ? 'Data final' : auditLocalDate(_endDate!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (compact)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    key: const ValueKey<String>('audit-apply-filters'),
                    onPressed: () {
                      Navigator.of(sheetContext!).pop();
                      _applyFilters();
                    },
                    child: const Text('Aplicar filtros'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const ValueKey<String>('audit-clear-filters-sheet'),
                    onPressed: () {
                      Navigator.of(sheetContext!).pop();
                      _clearFilters();
                    },
                    child: const Text('Limpar filtros'),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    key: const ValueKey<String>('audit-cancel-filters'),
                    onPressed: () => Navigator.of(sheetContext!).pop(),
                    child: const Text('Cancelar'),
                  ),
                ],
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton(
                    key: const ValueKey<String>('audit-apply-filters'),
                    onPressed: _applyFilters,
                    child: const Text('Aplicar filtros'),
                  ),
                  TextButton(
                    key: const ValueKey<String>('audit-clear-filters-panel'),
                    onPressed: _clearFilters,
                    child: const Text('Limpar filtros'),
                  ),
                  if (_hasPendingFilterChanges)
                    TextButton(
                      key: const ValueKey<String>('audit-discard-filters'),
                      onPressed: _discardDraftChanges,
                      child: const Text('Descartar alterações'),
                    ),
                  TextButton(
                    onPressed: () => setState(() => _filterPanelOpen = false),
                    child: const Text('Fechar'),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _buildExportFeedback() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final adminColors = AppTheme.adminColors(theme);
    final exporting = _isExporting;
    final failed = _exportFailed;
    final tone = exporting
        ? adminColors.info
        : failed
            ? adminColors.danger
            : _exportHadData
                ? adminColors.success
                : adminColors.neutral;
    final icon = exporting
        ? Icons.hourglass_top_rounded
        : failed
            ? Icons.error_outline_rounded
            : _exportHadData
                ? Icons.check_circle_outline_rounded
                : Icons.info_outline_rounded;

    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey<String>('audit-export-status'),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: tone.container,
          border: Border.all(
            color: tone.foreground.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: tone.foreground),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _exportStatus ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tone.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_isExporting) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Todos os registros dos filtros aplicados • timestamps em UTC.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: tone.foreground,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_isExporting)
                    LinearProgressIndicator(
                      key: const ValueKey<String>('audit-export-progress'),
                      minHeight: 2,
                      color: tone.foreground,
                      backgroundColor:
                          colorScheme.surface.withValues(alpha: 0.35),
                      semanticsLabel: 'Exportando registros de auditoria',
                    ),
                ],
              ),
            ),
            if (failed)
              TextButton(
                key: const ValueKey<String>('audit-export-retry'),
                onPressed: _exportEvents,
                child: const Text('Tentar novamente'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults({required bool compact}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 24,
        4,
        compact ? 16 : 24,
        16,
      ),
      child: _isLoading
          ? WorkspaceSkeletonRegion(
              label: 'Carregando eventos de auditoria',
              child: AuditLoadingSkeleton(compact: compact),
            )
          : _error != null && _events.isEmpty
              ? _buildErrorState()
              : _events.isEmpty
                  ? _buildEmptyState()
                  : Column(
                      children: [
                        Expanded(
                          child: compact ? _buildCards() : _buildTable(),
                        ),
                        _buildFooter(),
                      ],
                    ),
    );
  }

  Widget _buildTable() {
    return Container(
      key: const ValueKey<String>('audit-events-table'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          const AuditEventTableHeader(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final event = _events[index];
                return AuditEventTableRow(
                  key: ValueKey<String>('audit-event-row-${event.id}'),
                  event: event,
                  actionLabel: _eventActionLabel(event.action),
                  resultLabel: _eventResultLabel(event.result),
                  onTap: () => _openEventDetails(event),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCards() {
    return ListView.separated(
      key: const ValueKey<String>('audit-events-cards'),
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 4),
      itemCount: _events.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final event = _events[index];
        return AuditEventCard(
          key: ValueKey<String>('audit-event-card-${event.id}'),
          event: event,
          actionLabel: _eventActionLabel(event.action),
          resultLabel: _eventResultLabel(event.result),
          onTap: () => _openEventDetails(event),
        );
      },
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        child: Semantics(
          liveRegion: true,
          child: Container(
            key: const ValueKey<String>('audit-error-state'),
            constraints: const BoxConstraints(maxWidth: 560),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border.all(color: colorScheme.outline),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: colorScheme.error,
                  size: 28,
                ),
                const SizedBox(height: 10),
                Text(
                  'Não foi possível carregar a auditoria.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _error ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _loadEvents(refresh: true),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasFilters = _appliedFilterCount > 0;
    return Center(
      child: SingleChildScrollView(
        child: Semantics(
          liveRegion: true,
          child: Container(
            key: const ValueKey<String>('audit-empty-state'),
            constraints: const BoxConstraints(maxWidth: 560),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.manage_search_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 30,
                ),
                const SizedBox(height: 10),
                Text(
                  'Nenhum evento de auditoria encontrado.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  hasFilters
                      ? 'Ajuste os filtros aplicados para ampliar a consulta.'
                      : 'A empresa ainda não possui eventos registrados.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                if (hasFilters) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.filter_alt_off_rounded),
                    label: const Text('Limpar filtros'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_hasMore) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoadingMore) ...[
              WorkspaceSkeletonRegion(
                label: 'Carregando mais eventos de auditoria',
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: WorkspaceSkeletonList(
                    count: 2,
                    leadingSize: null,
                    spacing: 8,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  'Carregando mais eventos...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_error != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  'Erro: $_error',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => _loadEvents(retry: true),
                child: const Text('Tentar novamente'),
              ),
            ],
            OutlinedButton(
              key: const ValueKey<String>('audit-load-more'),
              focusNode: _loadMoreFocusNode,
              onPressed: _error != null ? null : () => _loadEvents(),
              child: const Text('Carregar mais eventos'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Semantics(
        liveRegion: true,
        focusable: true,
        child: Focus(
          focusNode: _endOfResultsFocusNode,
          child: Builder(
            builder: (context) => Container(
              key: const ValueKey<String>('audit-end-of-list'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border.all(
                  color: Focus.of(context).hasFocus
                      ? AppTheme.adminColors(theme).selectedIndicator
                      : colorScheme.outlineVariant,
                  width: Focus.of(context).hasFocus ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 17,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Todos os eventos carregados.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
