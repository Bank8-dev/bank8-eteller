// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:ETeller
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import '../app_context.dart';

/// Statements page — list the statements generated for one account
/// (`GET /v1/accounts/{id}/statements`, gate
/// `bank8:ledger:accounts:read`). Statement documents themselves are
/// fetched through the storage signed-URL path by the account detail
/// flow; this page surfaces the statement list + metadata.
class StatementsPage extends StatefulWidget {
  final String accountId;
  const StatementsPage({super.key, required this.accountId});
  @override State<StatementsPage> createState() => _StatementsPageState();
}

class _StatementsPageState extends State<StatementsPage> {
  List<dynamic>? _statements;
  bool _loading = true;
  String? _message;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final ctx = ETellerContextProvider.of(context)!;
    try {
      final res = await ctx.services!.ledger
          .get('/v1/accounts/${widget.accountId}/statements');
      _statements = (res.data?['statements'] ?? res.data?['items'] ??
              res.data?['data'] ?? []) as List<dynamic>? ?? [];
    } catch (_) {}
    setState(() { _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      appBar: AppBar(title: const Text('Statements')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Statements — ${widget.accountId}',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            if (_message != null) Text(_message!),
            const SizedBox(height: 8),
            Expanded(
              child: _statements == null || _statements!.isEmpty
                ? const Text('No statements')
                : ListView.builder(
                    itemCount: _statements!.length,
                    itemBuilder: (ctx, i) {
                      final s = _statements![i] as Map<String, dynamic>;
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.description),
                          title: Text(
                              'Statement ${s['id'] ?? ''}'),
                          subtitle: Text(
                              'Period: ${s['period_start'] ?? '—'} → ${s['period_end'] ?? '—'}'
                              ' · Generated: ${s['generated_at'] ?? s['created_at'] ?? '—'}'),
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}