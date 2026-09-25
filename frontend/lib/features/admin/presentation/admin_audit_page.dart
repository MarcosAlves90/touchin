import 'package:flutter/material.dart';
import 'package:touchin_flutter/contracts/audit.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';

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
  List<AuditEventResponse> _events = [];
  bool _hasMore = true;

  int _page = 1;
  final int _limit = 50;
  
  final ScrollController _scrollController = ScrollController();

  DateTime? _startDate;
  DateTime? _endDate;
  final _actorUserIdController = TextEditingController();
  final _actionController = TextEditingController();
  final _entityTypeController = TextEditingController();
  final _projectIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadEvents(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _actorUserIdController.dispose();
    _actionController.dispose();
    _entityTypeController.dispose();
    _projectIdController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _loadEvents();
      }
    }
  }

  Future<void> _loadEvents({bool refresh = false}) async {
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

      final api = widget.api ?? TouchInApi();
      final actorUserId = _actorUserIdController.text.trim().isEmpty ? null : _actorUserIdController.text.trim();
      final action = _actionController.text.trim().isEmpty ? null : _actionController.text.trim();
      final entityType = _entityTypeController.text.trim().isEmpty ? null : _entityTypeController.text.trim();
      final projectId = _projectIdController.text.trim().isEmpty ? null : _projectIdController.text.trim();

      final newEvents = await api.listAuditEvents(
        page: _page,
        limit: _limit,
        startDate: _startDate,
        endDate: _endDate,
        actorUserId: actorUserId,
        action: action,
        entityType: entityType,
        projectId: projectId,
      );

      setState(() {
        if (newEvents.length < _limit) {
          _hasMore = false;
        }
        _events.addAll(newEvents);
        _page++;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final initialDate = isStart ? _startDate ?? DateTime.now() : _endDate ?? DateTime.now();
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
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _actorUserIdController,
                    decoration: const InputDecoration(labelText: 'Actor User ID', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _actionController,
                    decoration: const InputDecoration(labelText: 'Action', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _entityTypeController,
                    decoration: const InputDecoration(labelText: 'Entity Type', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _projectIdController,
                    decoration: const InputDecoration(labelText: 'Project ID', isDense: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _pickDate(true),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_startDate != null ? _startDate!.toIso8601String().split('T').first : 'Data Inicial'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _pickDate(false),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_endDate != null ? _endDate!.toIso8601String().split('T').first : 'Data Final'),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => _loadEvents(refresh: true),
                  child: const Text('Apply Filters'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    _actorUserIdController.clear();
                    _actionController.clear();
                    _entityTypeController.clear();
                    _projectIdController.clear();
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _events.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _loadEvents(refresh: true),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _events.isEmpty
                      ? const Center(child: Text('No audit events found.'))
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: _events.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _events.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            final event = _events[index];
                            return ListTile(
                              title: Text('${event.action} - ${event.result}'),
                              subtitle: Text(
                                'Ator: ${event.actorUserId ?? 'N/A'}\n'
                                'Recurso: ${event.entityType} (${event.entityId})\n'
                                'Projeto: ${event.projectId ?? 'N/A'}',
                              ),
                              isThreeLine: true,
                              trailing: Text(event.timestamp.toLocal().toString().split('.').first),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
