// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:ETeller
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import '../app_context.dart';

class ShiftSummaryPage extends StatelessWidget {
  const ShiftSummaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctx = ETellerContextProvider.of(context)!;
    final log = ctx.sessionLog;
    int deposits = 0, withdrawals = 0, transfers = 0, cheques = 0;
    for (final e in log) {
      switch (e['type']) {
        case 'inbound_hard_settlement': deposits++; break;
        case 'outbound_hard_settlement': withdrawals++; break;
        case 'transfer': transfers++; break;
        case 'inbound_authorisation': cheques++; break;
      }
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Shift Summary', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _SummaryRow(label: 'Total Transactions', value: '${log.length}'),
                  _SummaryRow(label: 'Cash Deposits', value: '$deposits'),
                  _SummaryRow(label: 'Cheque Deposits (Pending)', value: '$cheques'),
                  _SummaryRow(label: 'Cash Withdrawals', value: '$withdrawals'),
                  _SummaryRow(label: 'Transfers', value: '$transfers'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Transaction Log', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Expanded(
            child: log.isEmpty
              ? const Text('No transactions this session')
              : ListView.builder(
                  itemCount: log.length,
                  itemBuilder: (ctx, i) {
                    final e = log[i];
                    return ListTile(
                      leading: Icon(_iconForType(e['type'] as String? ?? '')),
                      title: Text('${e['description'] ?? e['type']}'),
                      subtitle: Text('${e['amount']} ${e['denomination']} · ${e['timestamp']?.toString().substring(0, 19)}'),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) => switch (type) {
    'inbound_hard_settlement' => Icons.payments,
    'inbound_authorisation' => Icons.receipt_long,
    'outbound_hard_settlement' => Icons.atm,
    'transfer' => Icons.swap_horiz,
    _ => Icons.receipt,
  };
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [SizedBox(width: 200, child: Text(label)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]));
}