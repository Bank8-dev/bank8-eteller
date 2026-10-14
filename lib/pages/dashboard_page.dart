// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:ETeller
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import '../app_context.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    final ctx = ETellerContextProvider.of(context)!;
    final user = ctx.auth.user;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome, ${user?.displayName ?? user?.email ?? 'Teller'}', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12, runSpacing: 12,
            children: [
              _ActionCard(icon: Icons.payments, label: 'Cash Deposit', color: Colors.green, onTap: () => ctx.navigate?.call('/cash-deposit')),
              _ActionCard(icon: Icons.receipt_long, label: 'Cheque Deposit', color: Colors.blue, onTap: () => ctx.navigate?.call('/cheque-deposit')),
              _ActionCard(icon: Icons.atm, label: 'Withdrawal', color: Colors.orange, onTap: () => ctx.navigate?.call('/withdrawal')),
              _ActionCard(icon: Icons.swap_horiz, label: 'Transfer', color: Colors.purple, onTap: () => ctx.navigate?.call('/transfer')),
              _ActionCard(icon: Icons.person_add, label: 'Onboard Customer', color: Colors.teal, onTap: () => ctx.navigate?.call('/onboard-customer')),
              _ActionCard(icon: Icons.account_balance, label: 'Open Account', color: Colors.indigo, onTap: () => ctx.navigate?.call('/open-account')),
              // Ops review surfaces (ledger jobs/DLQ + postings review).
              _ActionCard(icon: Icons.fact_check, label: 'Posting Batches', color: Colors.blueGrey, onTap: () => ctx.navigate?.call('/posting-batches')),
              _ActionCard(icon: Icons.report_problem, label: 'DLQ', color: Colors.redAccent, onTap: () => ctx.navigate?.call('/dlq')),
            ],
          ),
          const SizedBox(height: 32),
          Text('Today\'s Summary', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Transactions this session: ${ctx.sessionLog.length}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _ActionCard({required this.icon, required this.label, required this.color, this.onTap});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 160, height: 100,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}