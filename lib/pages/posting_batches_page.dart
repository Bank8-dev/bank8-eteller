// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:ETeller
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import '../app_context.dart';

/// Posting-batch review page — inspect posting batches
/// (`GET /v1/postings` + `GET /v1/postings/{id}`
/// + `GET /v1/postings/{id}/instructions`, gates
/// `bank8:ledger:postings:read`). The teller reviews what a batch
/// actually committed — the read-your-writes check for counter work.
class PostingBatchesPage extends StatefulWidget {
  const PostingBatchesPage({super.key});
  @override State<PostingBatchesPage> createState() => _PostingBatchesPageState();
}

class _PostingBatchesPageState extends State<PostingBatchesPage> {
  List<dynamic>? _postings;
  bool _loading = true;
  String? _message;
  String? _expandedId;
  List<dynamic>? _expandedInstructions;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final ctx = ETellerContextProvider.of(context)!;
    try {
      final res = await ctx.services!.ledger.get('/v1/postings');
      _postings = (res.data?['postings'] ?? res.data?['items'] ??
              res.data?['data'] ?? []) as List<dynamic>? ?? [];
    } catch (_) {}
    setState(() { _loading = false; });
  }

  Future<void> _openInstructions(String postingId) async {
    final ctx = ETellerContextProvider.of(context)!;
    final res = await ctx.services!.ledger.get('/v1/postings/$postingId/instructions');
    setState(() {
      _expandedId = postingId;
      _expandedInstructions =
          (res.data?['instructions'] ?? res.data?['items'] ??
                  res.data?['data'] ?? []) as List<dynamic>? ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Posting Batches', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          if (_message != null) Text(_message!),
          const SizedBox(height: 8),
          Expanded(
            child: _postings == null || _postings!.isEmpty
              ? const Text('No postings')
              : ListView.builder(
                  itemCount: _postings!.length,
                  itemBuilder: (ctx, i) {
                    final p = _postings![i] as Map<String, dynamic>;
                    final id = p['id'] as String? ?? '';
                    final expanded = _expandedId == id;
                    return Card(
                      child: ExpansionTile(
                        initiallyExpanded: expanded,
                        title: Text('Batch $id'),
                        subtitle: Text(
                            'Status: ${p['status'] ?? '—'}'
                            ' · Instructions: ${p['instruction_count'] ?? '—'}'
                            ' · ${p['created_at'] ?? ''}'),
                        onExpansionChanged: (open) {
                          if (open) _openInstructions(id);
                        },
                        children: [
                          if (_expandedInstructions != null &&
                              _expandedInstructions!.isEmpty)
                            const ListTile(title: Text('No instructions')),
                          ...?_expandedInstructions?.map((ins) => ListTile(
                                dense: true,
                                title: Text(
                                    '${ins['instruction_type'] ?? ''} — ${ins['amount'] ?? ''} ${ins['denomination'] ?? ''}'),
                                subtitle: Text(
                                    'debit ${ins['debit_account'] ?? '—'} → credit ${ins['credit_account'] ?? '—'}'),
                              )),
                        ],
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}