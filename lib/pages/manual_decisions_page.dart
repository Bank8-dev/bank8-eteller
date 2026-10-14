// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:ETeller
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import '../app_context.dart';

class ManualDecisionsPage extends StatefulWidget {
  const ManualDecisionsPage({super.key});
  @override State<ManualDecisionsPage> createState() => _ManualDecisionsPageState();
}

class _ManualDecisionsPageState extends State<ManualDecisionsPage> {
  List<dynamic>? _decisions;
  bool _loading = true;
  String? _message;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final ctx = ETellerContextProvider.of(context)!;
    try {
      final res = await ctx.services!.payments.get('/v1/manual-decisions');
      _decisions = (res.data?['items'] ?? res.data?['data'] ?? []) as List<dynamic>? ?? [];
    } catch (_) {}
    setState(() { _loading = false; });
  }

  Future<void> _submit(String id, String decision) async {
    final ctx = ETellerContextProvider.of(context)!;
    final res = await ctx.services!.payments.post('/v1/manual-decisions/$id/submit', body: {'decision': decision});
    setState(() => _message = res.isSuccess ? 'Decision submitted: $decision' : 'Failed');
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
          Text('Manual Decisions', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          if (_message != null) Text(_message!),
          const SizedBox(height: 8),
          Expanded(
            child: _decisions == null || _decisions!.isEmpty
              ? const Text('No pending decisions')
              : ListView.builder(
                  itemCount: _decisions!.length,
                  itemBuilder: (ctx, i) {
                    final d = _decisions![i] as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        title: Text('Decision ${d['id']}'),
                        subtitle: Text('Status: ${d['status']}'),
                        trailing: Wrap(children: [
                          TextButton(onPressed: () => _submit(d['id'] as String, 'approve'), child: const Text('Approve')),
                          TextButton(onPressed: () => _submit(d['id'] as String, 'reject'), child: const Text('Reject')),
                        ]),
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