import 'package:flutter/material.dart';
import 'package:touchin_flutter/contracts/audit.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_shell.dart';

class AdminAuditPage extends StatefulWidget {
  const AdminAuditPage({super.key, this.api});

  final TouchInApi? api;

  @override
  State<AdminAuditPage> createState() => _AdminAuditPageState();
}

class _AdminAuditPageState extends State<AdminAuditPage> {
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  final List<AuditEventResponse> _events = [];
  bool _hasMore = true;
  int _requestGeneration = 0;
  late final TouchInApi _api;

  int _page = 1;
  final int _limit = 50;

  final ScrollController _scrollController = ScrollController();
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

  Future<void> _loadEvents({bool refresh = false}) async {
    if (!refresh && (_isLoading || _isLoadingMore || !_hasMore)) return;
    if (refresh) _requestGeneration++;
    final generation = _requestGeneration;
    final requestedPage = refresh ? 1 : _page;
    try {
      if (refresh) {
        setState(() {
          _isLoading = true;
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

      final actorUserId = _actorUserIdController.text.trim().isEmpty
          ? null
          : _actorUserIdController.text.trim();
      final action = _actionController.text.trim().isEmpty
          ? null
          : _actionController.text.trim();
      final entityType = _entityTypeController.text.trim().isEmpty
          ? null
          : _entityTypeController.text.trim();
      final entityId = _entityIdController.text.trim().isEmpty
          ? null
          : _entityIdController.text.trim();
      final projectId = _projectIdController.text.trim().isEmpty
          ? null
          : _projectIdController.text.trim();
      final result = _resultController.text.trim().isEmpty
          ? null
          : _resultController.text.trim();

      final newEvents = await _api.listAuditEvents(
        page: requestedPage,
        limit: _limit,
        startDate: _startDate,
        endDate: _endDate,
        actorUserId: actorUserId,
        action: action,
        entityType: entityType,
        entityId: entityId,
        projectId: projectId,
        result: result,
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

  Future<void> _pickDate(bool isStart) async {
    final initialDate =
        isStart ? _startDate ?? DateTime.now() : _endDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Widget _buildFilters() {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.52,
      ),
      child: SingleChildScrollView(
        child: Card(
          margin: const EdgeInsets.all(8.0),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900
                    ? 3
                    : constraints.maxWidth >= 540
                        ? 2
                        : 1;
                const spacing = 8.0;
                final fieldWidth =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Filtros da auditoria',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        SizedBox(
                            width: fieldWidth,
                            child: TextField(
                              controller: _actorUserIdController,
                              decoration: const InputDecoration(
                                  labelText: 'Actor User ID', isDense: true),
                            )),
                        SizedBox(
                            width: fieldWidth,
                            child: TextField(
                              controller: _actionController,
                              decoration: const InputDecoration(
                                  labelText: 'Action', isDense: true),
                            )),
                        SizedBox(
                            width: fieldWidth,
                            child: TextField(
                              controller: _entityTypeController,
                              decoration: const InputDecoration(
                                  labelText: 'Entity Type', isDense: true),
                            )),
                        SizedBox(
                            width: fieldWidth,
                            child: TextField(
                              controller: _entityIdController,
                              decoration: const InputDecoration(
                                  labelText: 'Entity ID', isDense: true),
                            )),
                        SizedBox(
                            width: fieldWidth,
                            child: TextField(
                              controller: _projectIdController,
                              decoration: const InputDecoration(
                                  labelText: 'Project ID', isDense: true),
                            )),
                        SizedBox(
                            width: fieldWidth,
                            child: TextField(
                              controller: _resultController,
                              decoration: const InputDecoration(
                                  labelText: 'Result', isDense: true),
                            )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () => _pickDate(true),
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(_startDate != null
                              ? _startDate!.toIso8601String().split('T').first
                              : 'Data Inicial'),
                        ),
                        TextButton.icon(
                          onPressed: () => _pickDate(false),
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(_endDate != null
                              ? _endDate!.toIso8601String().split('T').first
                              : 'Data Final'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 52),
                          ),
                          onPressed: () => _loadEvents(refresh: true),
                          child: const Text('Apply Filters'),
                        ),
                        TextButton(
                          onPressed: () {
                            _actorUserIdController.clear();
                            _actionController.clear();
                            _entityTypeController.clear();
                            _entityIdController.clear();
                            _projectIdController.clear();
                            _resultController.clear();
                            setState(() {
                              _startDate = null;
                              _endDate = null;
                            });
                            _loadEvents(refresh: true);
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WorkspaceScaffold(
      sidebar: const WorkspaceSidebar(
        title: 'Trilha de auditoria',
        description:
            'Consulte eventos registrados e filtre por recurso, ator e período.',
        summaryChildren: [],
        highlightChips: [],
      ),
      contentScrollable: false,
      contentBuilder: (context, isWide) => Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                    semanticsLabel: 'Carregando eventos de auditoria',
                  ))
                : _error != null && _events.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Semantics(
                              liveRegion: true,
                              child: Text('Erro: $_error'),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _loadEvents(refresh: true),
                              child: const Text('Tentar novamente'),
                            ),
                          ],
                        ),
                      )
                    : _events.isEmpty
                        ? const Center(
                            child:
                                Text('Nenhum evento de auditoria encontrado.'))
                        : Column(
                            children: [
                              Expanded(
                                child: ListView.builder(
                                  controller: _scrollController,
                                  itemCount: _events.length,
                                  itemBuilder: (context, index) {
                                    final event = _events[index];
                                    return Material(
                                      type: MaterialType.transparency,
                                      child: ListTile(
                                        title: Text(
                                            '${event.action} - ${event.result}'),
                                        subtitle: Text(
                                          'Ator: ${event.actorUserId ?? 'N/A'}\n'
                                          'Recurso: ${event.entityType} (${event.entityId})\n'
                                          'Projeto: ${event.projectId ?? 'N/A'}',
                                        ),
                                        isThreeLine: true,
                                        trailing: Text(event.timestamp
                                            .toLocal()
                                            .toString()
                                            .split('.')
                                            .first),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: _hasMore
                                    ? Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          OutlinedButton(
                                            focusNode: _loadMoreFocusNode,
                                            onPressed: () {
                                              if (!_isLoadingMore) {
                                                _loadEvents();
                                              }
                                            },
                                            child: const Text(
                                                'Carregar mais eventos'),
                                          ),
                                          if (_isLoadingMore) ...[
                                            const SizedBox(height: 8),
                                            Semantics(
                                              liveRegion: true,
                                              child: Text(
                                                  'Carregando mais eventos'),
                                            ),
                                          ],
                                        ],
                                      )
                                    : Semantics(
                                        liveRegion: true,
                                        focusable: true,
                                        child: Focus(
                                          focusNode: _endOfResultsFocusNode,
                                          child: Builder(
                                            builder: (context) => Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color:
                                                      Focus.of(context).hasFocus
                                                          ? Theme.of(context)
                                                              .colorScheme
                                                              .primary
                                                          : Colors.transparent,
                                                  width: 2,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'Todos os eventos de auditoria foram carregados.',
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}
