// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:ETeller
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import '../app_context.dart';
import '../url_router.dart';
import 'shared.dart';
import 'account_detail_page.dart';

class CustomerDetailPage extends StatefulWidget {
  final String customerId;
  const CustomerDetailPage({super.key, required this.customerId});
  @override State<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  Map<String, dynamic>? _customer;
  List<dynamic>? _accounts;
  bool _loading = true;
  // §3.1.3 — set when the delegation restore window ends without a service
  // registry (delegation dead / restore failed). The page then shows an
  // explicit message instead of a blank or crashed view.
  bool _restoreFailed = false;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final ctx = ETellerContextProvider.of(context)!;
    try {
      // §3.1.3 — `services` is null while `_restoreDelegation` is still
      // polling `GET /delegate/status` after a reload. Retry briefly instead
      // of crashing on the null-check operator.
      Map<String, dynamic>? customer;
      List<dynamic>? accounts;
      bool restored = false;
      for (int attempt = 0; attempt < 3 && !restored; attempt++) {
        final services = ctx.services;
        if (services != null) {
          final custRes =
              await services.ledger.get('/v1/customers/${widget.customerId}');
          final acctRes = await services.ledger.get('/v1/accounts',
              queryParams: {'customer_id': widget.customerId});
          customer = custRes.data;
          accounts = (acctRes.data?['accounts'] ?? acctRes.data?['data'])
              as List<dynamic>? ?? [];
          restored = true;
          break;
        }
        await Future.delayed(const Duration(seconds: 1));
      }
      if (mounted) {
        setState(() {
          _customer = customer;
          _accounts = accounts;
          _loading = false;
          // Registry still missing after the retry window: the restore did
          // not complete — tell the user instead of showing empty data.
          _restoreFailed = !restored;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_restoreFailed) {
      // §3.1.3 — the delegation restore never produced a service registry.
      return Scaffold(
        appBar: AppBar(title: const Text('Customer')),
        body: const Center(
          child: Text(
            'Restoring customer access… Please re-select the customer.',
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(_customer?['display_name'] as String? ?? 'Customer')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${_customer?['email'] ?? '—'}'),
            Text('Phone: ${_customer?['phone'] ?? '—'}'),
            const SizedBox(height: 24),
          Text('Accounts', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Expanded(
              child: _accounts == null || _accounts!.isEmpty
                ? const Text('No accounts')
                : ListView.builder(
                    itemCount: _accounts!.length,
                    itemBuilder: (ctx, i) {
                      final a = _accounts![i] as Map<String, dynamic>;
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.account_balance),
                          title: Text(a['nickname'] as String? ?? a['id'] as String? ?? 'Unknown'),
                          subtitle: Text('${a['account_type'] ?? ''} · ${a['denomination'] ?? ''} · ${a['status'] ?? ''}'),
                          onTap: () {
                            final accountId = a['id'] as String;
                            pushRoute('/accounts/$accountId');
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => AccountDetailPage(accountId: accountId),
                            ));
                          },
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