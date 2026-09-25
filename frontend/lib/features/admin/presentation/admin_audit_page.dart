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
  bool _isLoading = true;
  String? _error;
  List<AuditEventResponse>? _events;

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
      final api = widget.api ?? TouchInApi();
      final events = await api.listAuditEvents();
      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadEvents,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_events == null || _events!.isEmpty) {
      return const Center(child: Text('No audit events found.'));
    }

    return ListView.builder(
      itemCount: _events!.length,
      itemBuilder: (context, index) {
        final event = _events![index];
        return ListTile(
          title: Text(event.action),
          subtitle: Text('Entity: ${event.entityType} (${event.entityId})'),
          trailing: Text(event.timestamp.toLocal().toString()),
        );
      },
    );
  }
}
