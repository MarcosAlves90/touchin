import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:touchin_flutter/contracts/audit.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_shell.dart';
import 'package:touchin_flutter/theme/app_theme.dart';

class AdminAuditPage extends StatefulWidget {
  const AdminAuditPage({super.key});

  @override
  State<AdminAuditPage> createState() => _AdminAuditPageState();
}

class _AdminAuditPageState extends State<AdminAuditPage> {
  final TouchInApi _api = TouchInApi();
  List<AuditEventResponse>? _events;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final events = await _api.listAuditEvents();
      if (mounted) {
        setState(() {
          _events = events;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WorkspaceScaffold(
      title: 'Trilha de Auditoria',
      contentScrollable: false,
      contentBuilder: (context) {
        if (_isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Erro: $_error', style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadEvents,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          );
        }
        if (_events == null || _events!.isEmpty) {
          return const Center(child: Text('Nenhum log de auditoria encontrado.'));
        }

        return RefreshIndicator(
          onRefresh: _loadEvents,
          child: ListView.builder(
            itemCount: _events!.length,
            itemBuilder: (context, index) {
              final event = _events![index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ExpansionTile(
                  title: Text(event.action, style: AppTheme.headlineMedium),
                  subtitle: Text(
                    '${event.timestamp.toIso8601String()} - Usuário: ${event.actorUserId ?? "Sistema"}',
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ID: ${event.id}'),
                          Text('Entidade Afetada: ${event.entityType} (${event.entityId})'),
                          Text('Resultado: ${event.result}'),
                          if (event.projectId != null) Text('Projeto: ${event.projectId}'),
                          if (event.metadataPayload != null) ...[
                            const SizedBox(height: 8),
                            const Text('Metadata:'),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(8),
                              color: Colors.grey.withValues(alpha: 0.1),
                              child: Text(
                                const JsonEncoder.withIndent('  ').convert(event.metadataPayload),
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
