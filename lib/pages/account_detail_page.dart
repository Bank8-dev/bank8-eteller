// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:ETeller
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import '../app_context.dart';
import 'statements_page.dart';

class AccountDetailPage extends StatefulWidget {
  final String accountId;
  const AccountDetailPage({super.key, required this.accountId});
  @override State<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends State<AccountDetailPage> {
  Map<String, dynamic>? _account;
  List<dynamic>? _balances;
  List<dynamic>? _transactions;
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final ctx = ETellerContextProvider.of(context)!;
    try {
      final acctRes = await ctx.services!.ledger.get('/v1/accounts/${widget.accountId}');
      _account = acctRes.data;
      final balRes = await ctx.services!.ledger.get('/v1/accounts/${widget.accountId}/balances');
      _balances = (balRes.data?['balances'] ?? balRes.data?['data']) as List<dynamic>? ?? [];
      final txRes = await ctx.services!.ledger.get('/v1/accounts/${widget.accountId}/transactions');
      _transactions = (txRes.data?['transactions'] ?? txRes.data?['data']) as List<dynamic>? ?? [];
    } catch (_) {}
    setState(() { _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: Text(_account?['nickname'] as String? ?? 'Account')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${_account?['id']}', style: const TextStyle(fontFamily: 'monospace')),
            Text('Type: ${_account?['account_type']}'),
            Text('Status: ${_account?['status']}'),
            Text('Denomination: ${_account?['denomination']}'),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => StatementsPage(accountId: widget.accountId))),
                icon: const Icon(Icons.description),
                label: const Text('View Statements'),
              ),
            ),
            const SizedBox(height: 16),
            Text('Balances', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (_balances != null)
              ..._balances!.map((b) {
                final m = b as Map<String, dynamic>;
                return ListTile(
                  leading: Icon(m['phase'] == 'COMMITTED' ? Icons.check_circle : Icons.hourglass_empty),
                  title: Text('${m['phase'] ?? ''} · ${m['address'] ?? 'DEFAULT'}'),
                  trailing: Text('${m['amount'] ?? '0'} ${m['denomination'] ?? ''}'),
                );
              }),
            const SizedBox(height: 24),
            Text('Transactions', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Expanded(
              child: _transactions == null || _transactions!.isEmpty
                ? const Text('No transactions')
                : ListView.builder(
                    itemCount: _transactions!.length,
                    itemBuilder: (ctx, i) {
                      final t = _transactions![i] as Map<String, dynamic>;
                      final isCredit = t['direction'] == 'credit';
                      return ListTile(
                        leading: Icon(isCredit ? Icons.add_circle : Icons.remove_circle,
                            color: isCredit ? Colors.green : Colors.red),
                        title: Text('${t['amount']} ${t['denomination']}'),
                        subtitle: Text('${t['description'] ?? ''} · ${t['value_timestamp']?.toString().substring(0, 19) ?? ''}'),
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