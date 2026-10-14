// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:ETeller
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import '../app_context.dart';

class ApprovalTasksPage extends StatefulWidget {
  const ApprovalTasksPage({super.key});
  @override State<ApprovalTasksPage> createState() => _ApprovalTasksPageState();
}

class _ApprovalTasksPageState extends State<ApprovalTasksPage> {
  List<dynamic>? _tasks;
  bool _loading = true;
  String? _message;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final ctx = ETellerContextProvider.of(context)!;
    try {
      final res = await ctx.services!.payments.get('/v1/tasks');
      _tasks = (res.data?['items'] ?? res.data?['data'] ?? []) as List<dynamic>? ?? [];
    } catch (_) {}
    setState(() { _loading = false; });
  }

  Future<void> _action(String id, String action) async {
    final ctx = ETellerContextProvider.of(context)!;
    final res = await ctx.services!.payments.post('/v1/tasks/$id/$action', body: {});
    setState(() => _message = res.isSuccess ? 'Task $action' : 'Failed');
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
          Text('Approval Tasks', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          if (_message != null) Text(_message!),
          const SizedBox(height: 8),
          Expanded(
            child: _tasks == null || _tasks!.isEmpty
              ? const Text('No pending tasks')
              : ListView.builder(
                  itemCount: _tasks!.length,
                  itemBuilder: (ctx, i) {
                    final t = _tasks![i] as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        title: Text('Task ${t['id']}'),
                        subtitle: Text('Status: ${t['status']} · Type: ${t['type']}'),
                        trailing: Wrap(children: [
                          TextButton(onPressed: () => _action(t['id'] as String, 'claim'), child: const Text('Claim')),
                          TextButton(onPressed: () => _action(t['id'] as String, 'approve'), child: const Text('Approve')),
                          TextButton(onPressed: () => _action(t['id'] as String, 'reject'), child: const Text('Reject')),
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