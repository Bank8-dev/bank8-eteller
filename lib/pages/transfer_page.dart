// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:ETeller
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_context.dart';
import 'shared.dart';

class TransferPage extends StatefulWidget {
  const TransferPage({super.key});
  @override State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  List<Map<String, dynamic>> _accounts = [];
  Map<String, String> _customerNames = {};
  String? _debitId;
  String? _creditId;
  String? _denom;
  final _amountCtrl = TextEditingController();
  String? _message;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final ctx = ETellerContextProvider.of(context)!;
    _accounts = await fetchAllAccounts(ctx);
    _customerNames = await fetchCustomerNames(ctx);
    setState(() {});
  }

  Future<void> _submit() async {
    final ctx = ETellerContextProvider.of(context)!;
    if (_debitId == null || _creditId == null) { setState(() => _message = 'Select both accounts'); return; }
    if (_debitId == _creditId) { setState(() => _message = 'Accounts must be different'); return; }
    final minor = toMinorUnits(_amountCtrl.text);
    if (minor == '0') { setState(() => _message = 'Enter a valid amount'); return; }
    final result = await submitPosting(ctx, instructionType: 'transfer', debitAccountId: _debitId!, creditAccountId: _creditId!, amountMinor: minor, denomination: _denom ?? 'CAD', description: 'Teller-initiated transfer');
    setState(() => _message = result != null ? 'Transfer successful' : 'Transfer failed');
  }

  @override
  Widget build(BuildContext context) {
    final labels = _accounts.map((a) => accountLabel(a, _customerNames)).toList();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Transfer', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          Autocomplete<String>(optionsBuilder: (tev) => tev.text.isEmpty ? labels : labels.where((l) => l.toLowerCase().contains(tev.text.toLowerCase())), onSelected: (l) { final i = labels.indexOf(l); if (i >= 0) setState(() { _debitId = _accounts[i]['id'] as String; _denom = _accounts[i]['denomination'] as String?; }); }, fieldViewBuilder: (ctx, c, f, o) => TextField(controller: c, focusNode: f, decoration: const InputDecoration(labelText: 'From Account (Debit)'), onSubmitted: (_) => o())),
          const SizedBox(height: 16),
          Autocomplete<String>(optionsBuilder: (tev) => tev.text.isEmpty ? labels : labels.where((l) => l.toLowerCase().contains(tev.text.toLowerCase())), onSelected: (l) { final i = labels.indexOf(l); if (i >= 0) setState(() { _creditId = _accounts[i]['id'] as String; _denom ??= _accounts[i]['denomination'] as String?; }); }, fieldViewBuilder: (ctx, c, f, o) => TextField(controller: c, focusNode: f, decoration: const InputDecoration(labelText: 'To Account (Credit)'), onSubmitted: (_) => o())),
          const SizedBox(height: 16),
          TextField(controller: _amountCtrl, decoration: InputDecoration(labelText: 'Amount', prefixText: _denom != null ? '$_denom ' : null), keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(moneyInputRegex)]),
          const SizedBox(height: 24),
          FilledButton.icon(onPressed: _submit, icon: const Icon(Icons.swap_horiz), label: const Text('Submit Transfer')),
          if (_message != null) ...[const SizedBox(height: 16), Text(_message!, style: TextStyle(color: _message!.contains('success') ? Colors.green : Colors.red))],
        ],
      ),
    );
  }
}