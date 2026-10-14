// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:ETeller
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import '../app_context.dart';

class AccountManagementPage extends StatefulWidget {
  const AccountManagementPage({super.key});
  @override State<AccountManagementPage> createState() => _AccountManagementPageState();
}

class _AccountManagementPageState extends State<AccountManagementPage> {
  List<dynamic>? _accounts;
  bool _loading = true;
  String? _message;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final ctx = ETellerContextProvider.of(context)!;
    try {
      final res = await ctx.services!.ledger.get('/v1/accounts');
      _accounts = (res.data?['accounts'] ?? res.data?['data']) as List<dynamic>? ?? [];
    } catch (_) {}
    setState(() { _loading = false; });
  }

  Future<void> _updateStatus(String accountId, String status) async {
    final ctx = ETellerContextProvider.of(context)!;
    final res = await ctx.services!.ledger.put('/v1/accounts/$accountId', body: {'status': status});
    setState(() => _message = res.isSuccess ? 'Account $status' : 'Failed');
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
          Text('Account Management', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          if (_message != null) Text(_message!),
          const SizedBox(height: 8),
          Expanded(
            child: _accounts == null || _accounts!.isEmpty
              ? const Text('No accounts')
              : ListView.builder(
                  itemCount: _accounts!.length,
                  itemBuilder: (ctx, i) {
                    final a = _accounts![i] as Map<String, dynamic>;
                    final status = a['status'] as String? ?? 'active';
                    return Card(
                      child: ListTile(
                        leading: Icon(status == 'active' ? Icons.check_circle : Icons.block, color: status == 'active' ? Colors.green : Colors.red),
                        title: Text(a['nickname'] as String? ?? a['id'] as String? ?? 'Unknown'),
                        subtitle: Text('$status · ${a['account_type']}'),
                        trailing: PopupMenuButton<String>(
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'frozen', child: Text('Freeze')),
                            const PopupMenuItem(value: 'closed', child: Text('Close')),
                            const PopupMenuItem(value: 'active', child: Text('Reactivate')),
                          ],
                          onSelected: (v) => _updateStatus(a['id'] as String, v),
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