// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:ETeller
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import '../app_context.dart';

class PendingChequesPage extends StatefulWidget {
  const PendingChequesPage({super.key});
  @override State<PendingChequesPage> createState() => _PendingChequesPageState();
}

class _PendingChequesPageState extends State<PendingChequesPage> {
  List<Map<String, dynamic>> _pending = [];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final ctx = ETellerContextProvider.of(context)!;
    // Session log contains cheque deposits with type 'inbound_authorisation'
    _pending = ctx.sessionLog.where((e) => e['type'] == 'inbound_authorisation').toList();
    setState(() {});
  }

  Future<void> _settle(Map<String, dynamic> entry) async {
    final ctx = ETellerContextProvider.of(context)!;
    final chequeAcct = ctx.internalAccounts?.chequeClearing();
    if (chequeAcct == null) return;
    // Note: in a real implementation, we'd resolve the original customer account
    // from the posting. For this demo, we use the session log entry.
    setState(() => _message = 'Cheque ${entry['batch_id']} marked as cleared');
  }

  String? _message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pending Cheques', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          if (_pending.isEmpty)
            const Text('No pending cheques')
          else
            Expanded(
              child: ListView.builder(
                itemCount: _pending.length,
                itemBuilder: (ctx, i) {
                  final e = _pending[i];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.hourglass_empty, color: Colors.orange),
                      title: Text('${e['description'] ?? 'Cheque'}'),
                      subtitle: Text('${e['amount']} ${e['denomination']} · ${e['timestamp']?.toString().substring(0, 19)}'),
                      trailing: Wrap(
                        children: [
                          TextButton(onPressed: () => _settle(e), child: const Text('Mark Cleared')),
                          TextButton(onPressed: () { setState(() { _pending.removeAt(i); _message = 'Cheque bounced'; }); }, child: const Text('Mark Bounced')),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          if (_message != null) ...[const SizedBox(height: 16), Text(_message!)],
        ],
      ),
    );
  }
}