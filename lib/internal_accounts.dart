// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:ETeller
// SPDX-License-Identifier: Apache-2.0

// eTeller internal account resolver - caches platform internal accounts
// Resolves internal accounts by nickname for use as posting counterpart.
//
// Uses the STAFF-scoped ledger client (`services.staffLedger`, never
// delegation-stamped) and passes the app's runtime env id: internal
// accounts are seeded per CUSTOMER env while the staff token claims the
// staff auth env, so the ledger needs the org-validated `?env_id=`
// override for internal-account reads. Contract: apps/eteller/DESIGN.md §2.

import 'services.dart';

class InternalAccountResolver {
  final ETellerServices services;
  final String runtimeEnvId;
  Map<String, String> _cache = {}; // nickname → account_id
  Map<String, String> _denoms = {}; // nickname → denomination

  InternalAccountResolver(this.services, {required this.runtimeEnvId});

  Future<void> load() async {
    try {
      final res = await services.staffLedger.get('/v1/accounts', queryParams: {
        'account_type': 'internal',
        if (runtimeEnvId.isNotEmpty) 'env_id': runtimeEnvId,
      });
      final accounts = (res.data?['accounts'] ?? res.data?['data']) as List<dynamic>? ?? [];
      _cache = {};
      _denoms = {};
      for (final a in accounts) {
        final m = a as Map<String, dynamic>;
        final nickname = m['nickname'] as String?;
        final id = m['id'] as String?;
        final denom = m['denomination'] as String? ?? 'CAD';
        if (nickname != null && id != null) {
          _cache[nickname] = id;
          _denoms[nickname] = denom;
        }
      }
    } catch (_) {}
  }

  String? cashDeposit() => _cache['ledger:cash_deposit_account'];
  String? chequeClearing() => _cache['ledger:cheque_clearing_account'];
  String? liquidity() => _cache['ledger:liquidity_account'];
  String? clearing() => _cache['ledger:clearing_account'];
  String? suspense() => _cache['ledger:suspense_account'];
  String? byNickname(String nickname) => _cache[nickname];

  int get count => _cache.length;
  bool get isLoaded => _cache.isNotEmpty;
}