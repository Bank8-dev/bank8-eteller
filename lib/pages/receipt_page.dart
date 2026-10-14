// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:ETeller
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import '../app_context.dart';

class ReceiptPage extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final String tellerId;
  final String customerName;
  final String accountLabel;
  final String balanceAfter;

  const ReceiptPage({
    super.key,
    required this.transaction,
    required this.tellerId,
    required this.customerName,
    required this.accountLabel,
    required this.balanceAfter,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction Receipt')),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(child: Text('eTeller', style: Theme.of(context).textTheme.headlineSmall)),
                const Divider(),
                _row('Transaction ID', transaction['batch_id'] as String? ?? '—'),
                _row('Date/Time', DateTime.now().toIso8601String().substring(0, 19)),
                _row('Teller ID', tellerId),
                _row('Customer', customerName),
                _row('Account', accountLabel),
                _row('Type', _typeLabel(transaction['type'] as String? ?? '')),
                _row('Amount', '${transaction['amount']} ${transaction['denomination']}'),
                _row('Balance After', balanceAfter),
                _row('Status', 'Accepted'),
                const Divider(),
                Center(child: ElevatedButton.icon(onPressed: () => _print(), icon: const Icon(Icons.print), label: const Text('Print'))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))), Expanded(child: SelectableText(value))]));
  }

  String _typeLabel(String type) {
    return switch (type) {
      'inbound_hard_settlement' => 'Cash Deposit',
      'inbound_authorisation' => 'Cheque Deposit (Pending)',
      'outbound_hard_settlement' => 'Cash Withdrawal',
      'transfer' => 'Transfer',
      _ => type,
    };
  }

  void _print() {
    // Browser print dialog
  }
}