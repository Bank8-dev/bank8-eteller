// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:ETeller
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_context.dart';
import 'shared.dart';

class CashDepositPage extends StatefulWidget {
  const CashDepositPage({super.key});
  @override State<CashDepositPage> createState() => _CashDepositPageState();
}

class _CashDepositPageState extends State<CashDepositPage> {
  List<Map<String, dynamic>> _accounts = [];
  Map<String, String> _customerNames = {};
  String? _selectedAccountId;
  String? _selectedDenom;
  final _amountCtrl = TextEditingController();
  String? _message;
  String? _loadError;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final ctx = ETellerContextProvider.of(context)!;
    // Retry briefly: the page can mount while a route handoff/SSE event is
    // still settling, which aborts the first fetch (TypeError: Failed to
    // fetch). A teller sees the same transient failure — retry until the
    // list arrives or attempts run out.
    Object? lastError;
    for (int attempt = 0; attempt < 4; attempt++) {
      try {
        final accounts = await fetchAllAccounts(ctx);
        final names = await fetchCustomerNames(ctx);
        if (!mounted) return;
        setState(() {
          _accounts = accounts;
          _customerNames = names;
          _loadError = accounts.isEmpty
              ? 'ledger returned no accounts (status ok, empty list)'
              : null;
        });
        if (accounts.isNotEmpty) return;
      } catch (e) {
        lastError = e;
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
    if (!mounted) return;
    if (_accounts.isEmpty) {
      setState(() => _loadError = lastError?.toString() ?? 'no accounts after retries');
    }
  }

  Future<void> _submit() async {
    final ctx = ETellerContextProvider.of(context)!;
    if (_selectedAccountId == null) { setState(() => _message = 'Please select an account'); return; }
    final cashAcct = ctx.internalAccounts?.cashDeposit();
    if (cashAcct == null) { setState(() => _message = 'Cash deposit internal account not found'); return; }
    final minor = toMinorUnits(_amountCtrl.text);
    if (minor == '0') { setState(() => _message = 'Please enter a valid amount'); return; }
    final result = await submitPosting(ctx,
      instructionType: 'inbound_hard_settlement',
      debitAccountId: cashAcct,
      creditAccountId: _selectedAccountId!,
      amountMinor: minor,
      denomination: _selectedDenom ?? 'CAD',
      description: 'Cash deposit at branch',
    );
    setState(() => _message = result != null ? 'Cash deposited successfully' : 'Failed to deposit');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cash Deposit', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          // §3.1.1 — account options as ALWAYS-VISIBLE choice cards: both
          // Autocomplete and DropdownButton render overlay menus that are
          // not exposed to flt-semantics (invisible to screen readers and
          // e2e tests). Same state contract as before.
          if (_loadError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_loadError!, style: const TextStyle(color: Colors.red)),
            ),
          if (_accounts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No customer accounts available'),
            )
          else
            ..._accounts.map((a) {
              final id = a['id'] as String;
              final label = accountLabel(a, _customerNames);
              final selected = id == _selectedAccountId;
              return Card(
                color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
                child: ListTile(
                  leading: Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: selected ? Theme.of(context).colorScheme.primary : null,
                  ),
                  title: Text(label, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    setState(() {
                      _selectedAccountId = id;
                      _selectedDenom = a['denomination'] as String?;
                    });
                  },
                ),
              );
            }),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: _selectedDenom != null ? '$_selectedDenom ' : null,
              helperText: 'Enter amount in major units (e.g. 100.00)',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(moneyInputRegex)],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(onPressed: _submit, icon: const Icon(Icons.payments), label: const Text('Deposit Cash')),
          if (_message != null) ...[const SizedBox(height: 16), Text(_message!, style: TextStyle(color: _message!.contains('success') ? Colors.green : Colors.red))],
        ],
      ),
    );
  }
}