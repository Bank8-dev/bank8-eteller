// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:ETeller
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_context.dart';
import 'shared.dart';

class WithdrawalPage extends StatefulWidget {
  const WithdrawalPage({super.key});
  @override State<WithdrawalPage> createState() => _WithdrawalPageState();
}

class _WithdrawalPageState extends State<WithdrawalPage> {
  List<Map<String, dynamic>> _accounts = [];
  Map<String, String> _customerNames = {};
  String? _selectedAccountId;
  String? _selectedDenom;
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
    if (_selectedAccountId == null) { setState(() => _message = 'Please select an account'); return; }
    final cashAcct = ctx.internalAccounts?.cashDeposit();
    if (cashAcct == null) { setState(() => _message = 'Cash deposit account not found'); return; }
    final minor = toMinorUnits(_amountCtrl.text);
    if (minor == '0') { setState(() => _message = 'Please enter a valid amount'); return; }
    final result = await submitPosting(ctx,
      instructionType: 'outbound_hard_settlement',
      debitAccountId: _selectedAccountId!,
      creditAccountId: cashAcct,
      amountMinor: minor,
      denomination: _selectedDenom ?? 'CAD',
      description: 'Cash withdrawal at branch',
    );
    setState(() => _message = result != null ? 'Cash withdrawn successfully' : 'Failed to withdraw');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cash Withdrawal', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          Autocomplete<String>(
            optionsBuilder: (tev) {
              final q = tev.text.toLowerCase();
              if (q.isEmpty) return _accounts.map((a) => accountLabel(a, _customerNames));
              return _accounts.where((a) => accountLabel(a, _customerNames).toLowerCase().contains(q)).map((a) => accountLabel(a, _customerNames));
            },
            onSelected: (label) {
              final idx = _accounts.indexWhere((a) => accountLabel(a, _customerNames) == label);
              if (idx >= 0) setState(() { _selectedAccountId = _accounts[idx]['id'] as String; _selectedDenom = _accounts[idx]['denomination'] as String?; });
            },
            fieldViewBuilder: (ctx, ctrl, fn, ofs) => TextField(controller: ctrl, focusNode: fn, decoration: const InputDecoration(labelText: 'Customer Account'), onSubmitted: (_) => ofs()),
          ),
          const SizedBox(height: 16),
          TextField(controller: _amountCtrl, decoration: InputDecoration(labelText: 'Amount', prefixText: _selectedDenom != null ? '$_selectedDenom ' : null), keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(moneyInputRegex)]),
          const SizedBox(height: 24),
          FilledButton.icon(onPressed: _submit, icon: const Icon(Icons.atm), label: const Text('Withdraw Cash')),
          if (_message != null) ...[const SizedBox(height: 16), Text(_message!, style: TextStyle(color: _message!.contains('success') ? Colors.green : Colors.red))],
        ],
      ),
    );
  }
}