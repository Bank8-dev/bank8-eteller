// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:ETeller
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import '../app_context.dart';

class CustomerSearchPage extends StatefulWidget {
  final void Function(String customerId, String customerName, String customerEmail)? onCustomerSelected;
  const CustomerSearchPage({super.key, this.onCustomerSelected});
  @override State<CustomerSearchPage> createState() => _CustomerSearchPageState();
}

class _CustomerSearchPageState extends State<CustomerSearchPage> {
  List<dynamic>? _results;
  bool _loading = false;
  String? _error;
  final _searchCtrl = TextEditingController();

  /// Searches Ledger customers in the caller's org/env via BFF proxy.
  /// Results include `auth_user_id` — if non-null, the customer has an
  /// env-scoped Auth account (i.e. can self-serve via CIBA delegation).
  Future<void> _search() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final ctx = ETellerContextProvider.of(context)!;
      final envId = ctx.runtimeContext.environmentId;
      final resp = await ctx.services!.ledger.get('/v1/customers', queryParams: {
        'search': query,
        if (envId.isNotEmpty) 'env_id': envId,
      });
      if (!resp.isSuccess) {
        throw Exception('Customer search failed (${resp.statusCode}): ${resp.error ?? resp.data}');
      }
      // Ledger returns a bare JSON array; the ApiClient wraps it in {'data': [...]}.
      _results = resp.data?['data'] as List<dynamic>? ?? [];
    } catch (e) {
      _results = [];
      _error = e.toString();
    }
    setState(() { _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Customer Search', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: TextField(controller: _searchCtrl, decoration: const InputDecoration(labelText: 'Search by name or email'))),
              const SizedBox(width: 12),
              FilledButton(onPressed: _search, child: const Text('Search')),
            ],
          ),
          const SizedBox(height: 24),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null && !_loading)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (_results != null && !_loading)
            Expanded(
              child: _results!.isEmpty
                ? const Center(child: Text('No customers found'))
                : SingleChildScrollView(
                    child: Column(
                      children: _results!.map((c) {
                        final customer = c as Map<String, dynamic>;
                        final hasAuthAccount = (customer['auth_user_id'] as String?) != null && (customer['auth_user_id'] as String).isNotEmpty;
                        // Use resolved_display_name/resolved_email (from auth user)
                        // when display_name/email are empty on the customer row.
                        final displayName = (customer['display_name'] as String? ?? '').isNotEmpty
                            ? customer['display_name'] as String
                            : customer['resolved_display_name'] as String? ?? 'Unknown';
                        // Prefer resolved_email when the raw email is empty/missing
                        // (the DB stores "" not null, so ?? alone doesn't fall back).
                        final rawEmail = customer['email'] as String? ?? '';
                        final email = rawEmail.isNotEmpty
                            ? rawEmail
                            : customer['resolved_email'] as String? ?? '';
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.person),
                            title: Row(
                              children: [
                                Flexible(child: Text(displayName)),
                                if (hasAuthAccount) ...[
                                  const SizedBox(width: 8),
                                  Tooltip(
                                    message: 'Has an Auth account — can self-serve via CIBA',
                                    child: Icon(Icons.verified_user, size: 16, color: Theme.of(context).colorScheme.primary),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text('$email · ${customer['phone'] ?? ''}'),
                            onTap: () {
                              final id = customer['id'] as String;
                              if (widget.onCustomerSelected != null) {
                                widget.onCustomerSelected!(id, displayName, email);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
            ),
        ],
      ),
    );
  }
}