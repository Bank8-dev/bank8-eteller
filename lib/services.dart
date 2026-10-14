// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:ETeller
// SPDX-License-Identifier: Apache-2.0

// eTeller services — BFF proxy access layer for Ledger + Payments.
//
// BffApiClient, ApiResponse, and generateCorrelationId are re-exported
// from sentin8. ETellerServices is app-specific.

// Re-export shared types from the package.
export 'package:sentin8/sentin8.dart'
    show BffApiClient, ApiResponse, generateCorrelationId;

import 'package:sentin8/sentin8.dart';

/// Centralized service registry for eTeller.
class ETellerServices {
  final BffApiClient ledger;
  final BffApiClient payments;

  /// §3.1.2 — staff-scoped ledger client. NEVER stamped with the delegation
  /// id, so it keeps the staff session token even while a customer
  /// delegation is active. Used by the internal-account resolver: internal
  /// accounts (customer_id IS NULL) are never visible to holder tokens.
  late final BffApiClient staffLedger;

  ETellerServices._({required this.ledger, required this.payments, required String bffBaseUrl, String? csrfToken, String? correlationId}) {
    final base = bffBaseUrl.replaceAll(RegExp(r'/+$'), '');
    staffLedger = BffApiClient(bffBaseUrl: base, serviceName: 'bank8-ledger', csrfToken: csrfToken, correlationId: correlationId);
  }

  factory ETellerServices({
    required String bffBaseUrl,
    String? csrfToken,
    String? correlationId,
  }) {
    final base = bffBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return ETellerServices._(
      bffBaseUrl: bffBaseUrl,
      csrfToken: csrfToken,
      correlationId: correlationId,
      ledger: BffApiClient(bffBaseUrl: base, serviceName: 'bank8-ledger', csrfToken: csrfToken, correlationId: correlationId),
      payments: BffApiClient(bffBaseUrl: base, serviceName: 'bank8-payments', csrfToken: csrfToken, correlationId: correlationId),
    );
  }

  /// §4.3f (Option A) — customer-scoped registry for an ACTIVE CIBA
  /// delegation. Every request through these clients carries
  /// `X-BFF-Delegation: {delegationId}` so the BFF attaches the
  /// customer-approved, time-boxed delegated token (sub = customer,
  /// act = staff). When the delegation expires the shell must drop this
  /// registry — the base (non-delegated) clients see no customer data.
  factory ETellerServices.delegatedCustomer({
    required String bffBaseUrl,
    String? csrfToken,
    String? correlationId,
    required String delegationId,
  }) {
    final base = bffBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return ETellerServices._(
      bffBaseUrl: bffBaseUrl,
      csrfToken: csrfToken,
      correlationId: correlationId,
      ledger: BffApiClient(bffBaseUrl: base, serviceName: 'bank8-ledger', csrfToken: csrfToken, correlationId: correlationId, delegationId: delegationId),
      payments: BffApiClient(bffBaseUrl: base, serviceName: 'bank8-payments', csrfToken: csrfToken, correlationId: correlationId, delegationId: delegationId),
    );
  }
}