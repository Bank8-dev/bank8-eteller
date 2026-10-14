// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:ETeller
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import '../app_context.dart';

class CustomerOnboardingPage extends StatefulWidget {
  const CustomerOnboardingPage({super.key});
  @override State<CustomerOnboardingPage> createState() => _CustomerOnboardingPageState();
}

class _CustomerOnboardingPageState extends State<CustomerOnboardingPage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _message;
  String? _createdId;

  Future<void> _submit() async {
    final ctx = ETellerContextProvider.of(context)!;
    if (_nameCtrl.text.isEmpty) { setState(() => _message = 'Name required'); return; }
    final res = await ctx.services!.ledger.post('/v1/customers', body: {
      'display_name': _nameCtrl.text,
      'email': _emailCtrl.text.isNotEmpty ? _emailCtrl.text : null,
      'phone': _phoneCtrl.text.isNotEmpty ? _phoneCtrl.text : null,
    });
    if (res.isSuccess) {
      _createdId = res.data?['id'] as String?;
      setState(() => _message = 'Customer created: $_createdId');
    } else {
      setState(() => _message = 'Failed: ${res.error ?? res.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Onboard Customer', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name *')),
          const SizedBox(height: 16),
          TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 16),
          TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
          const SizedBox(height: 24),
          FilledButton.icon(onPressed: _submit, icon: const Icon(Icons.person_add), label: const Text('Create Customer')),
          if (_message != null) ...[const SizedBox(height: 16), Text(_message!, style: TextStyle(color: _createdId != null ? Colors.green : Colors.red))],
        ],
      ),
    );
  }
}