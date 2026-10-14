// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:ETeller
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import '../app_context.dart';

/// DLQ page — list the ledger's dead-letter queue entries and republish
/// them (`GET /v1/dlq` + `POST /v1/dlq/{id}/republish`; gates
/// `bank8:ledger:dlq:read` / `bank8:ledger:dlq:republish`). Ops surface —
/// reachable under the delegation window like the other customer-operation
/// pages (the DLQ rows are tenant-scoped to the delegated customer's env
/// via the BFF).
class DlqPage extends StatefulWidget {
  const DlqPage({super.key});
  @override State<DlqPage> createState() => _DlqPageState();
}

class _DlqPageState extends State<DlqPage> {
  List<dynamic>? _entries;
  bool _loading = true;
  String? _message;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final ctx = ETellerContextProvider.of(context)!;
    try {
      final res = await ctx.services!.ledger.get('/v1/dlq');
      _entries = (res.data?['items'] ?? res.data?['entries'] ??
              res.data?['data'] ?? []) as List<dynamic>? ?? [];
    } catch (_) {}
    setState(() { _loading = false; });
  }

  Future<void> _republish(String id) async {
    final ctx = ETellerContextProvider.of(context)!;
    final res = await ctx.services!.ledger.post('/v1/dlq/$id/republish', body: {});
    setState(() {
      _message = res.isSuccess ? 'Republished $id' : 'Republish failed';
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dead Letter Queue', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          if (_message != null) Text(_message!),
          const SizedBox(height: 8),
          Expanded(
            child: _entries == null || _entries!.isEmpty
              ? const Text('DLQ is empty')
              : ListView.builder(
                  itemCount: _entries!.length,
                  itemBuilder: (ctx, i) {
                    final e = _entries![i] as Map<String, dynamic>;
                    final id = e['id'] as String? ?? '';
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.error_outline),
                        title: Text('Message $id'),
                        subtitle: Text(
                          'Type: ${e['message_type'] ?? e['event_type'] ?? '—'}'
                          ' · Retries: ${e['retry_count'] ?? e['attempts'] ?? 0}'
                          ' · Error: ${e['error_message'] ?? '—'}'),
                        trailing: TextButton(
                          onPressed: () => _republish(id),
                          child: const Text('Republish'),
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}