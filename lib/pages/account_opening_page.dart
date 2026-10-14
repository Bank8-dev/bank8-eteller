// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:ETeller
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import '../app_context.dart';

class AccountOpeningPage extends StatefulWidget {
  const AccountOpeningPage({super.key});
  @override State<AccountOpeningPage> createState() => _AccountOpeningPageState();
}

class _AccountOpeningPageState extends State<AccountOpeningPage> {
  List<dynamic>? _products;
  List<dynamic>? _customers;
  String? _customerId;
  String? _productId;
  final _nicknameCtrl = TextEditingController();
  String _denom = 'CAD';
  String? _message;
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final ctx = ETellerContextProvider.of(context)!;
    try {
      final prodRes = await ctx.services!.ledger.get('/v1/products');
      _products = (prodRes.data?['products'] ?? prodRes.data?['data']) as List<dynamic>? ?? [];
      final custRes = await ctx.services!.ledger.get('/v1/customers');
      _customers = (custRes.data?['customers'] ?? custRes.data?['data']) as List<dynamic>? ?? [];
    } catch (_) {}
    setState(() { _loading = false; });
  }

  Future<void> _submit() async {
    final ctx = ETellerContextProvider.of(context)!;
    if (_customerId == null || _productId == null) { setState(() => _message = 'Select customer and product'); return; }
    final res = await ctx.services!.ledger.post('/v1/accounts', body: {
      'customer_id': _customerId,
      'product_id': _productId,
      'account_type': 'customer',
      'nickname': _nicknameCtrl.text.isNotEmpty ? _nicknameCtrl.text : null,
      'denomination': _denom,
    });
    setState(() => _message = res.isSuccess ? 'Account opened successfully' : 'Failed: ${res.error ?? res.statusCode}');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Open Account', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          DropdownButton<String>(value: _customerId, hint: const Text('Select Customer'), items: (_customers ?? []).map((c) => DropdownMenuItem(value: (c as Map<String, dynamic>)['id'] as String, child: Text(c['display_name'] as String? ?? 'Unknown'))).toList(), onChanged: (v) => setState(() => _customerId = v)),
          const SizedBox(height: 16),
          DropdownButton<String>(value: _productId, hint: const Text('Select Product'), items: (_products ?? []).map((p) => DropdownMenuItem(value: (p as Map<String, dynamic>)['id'] as String, child: Text(p['name'] as String? ?? 'Unknown'))).toList(), onChanged: (v) => setState(() => _productId = v)),
          const SizedBox(height: 16),
          TextField(controller: _nicknameCtrl, decoration: const InputDecoration(labelText: 'Account Nickname')),
          const SizedBox(height: 16),
          DropdownButton<String>(value: _denom, items: ['CAD', 'USD', 'EUR', 'GBP'].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(), onChanged: (v) => setState(() => _denom = v!)),
          const SizedBox(height: 24),
          FilledButton.icon(onPressed: _submit, icon: const Icon(Icons.account_balance), label: const Text('Open Account')),
          if (_message != null) ...[const SizedBox(height: 16), Text(_message!)],
        ],
      ),
    );
  }
}