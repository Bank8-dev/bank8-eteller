// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:ETeller
// SPDX-License-Identifier: Apache-2.0

// eTeller shared helpers — posting, formatting, account label

import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import '../app_context.dart';

// Fetch customer accounts for autocomplete
Future<List<Map<String, dynamic>>> fetchCustomerAccounts(ETellerContext ctx, String customerId) async {
  final res = await ctx.services!.ledger.get('/v1/accounts', queryParams: {'customer_id': customerId});
  final accounts = (res.data?['accounts'] ?? res.data?['data']) as List<dynamic>? ?? [];
  return accounts.cast<Map<String, dynamic>>();
}

// Fetch all customer accounts for autocomplete (all accounts including internal)
Future<List<Map<String, dynamic>>> fetchAllAccounts(ETellerContext ctx) async {
  final res = await ctx.services!.ledger.get('/v1/accounts');
  final accounts = (res.data?['accounts'] ?? res.data?['data']) as List<dynamic>? ?? [];
  return accounts.cast<Map<String, dynamic>>();
}

// Fetch customer names map
Future<Map<String, String>> fetchCustomerNames(ETellerContext ctx) async {
  try {
    final res = await ctx.services!.ledger.get('/v1/customers');
    final customers = (res.data?['customers'] ?? res.data?['data']) as List<dynamic>? ?? [];
    return {
      for (final c in customers)
        (c as Map<String, dynamic>)['id'] as String: _resolvedName(c),
    };
  } catch (_) {
    return {};
  }
}

/// Resolve a customer's display name: use ledger_customers.display_name if
/// non-empty, otherwise fall back to resolved_display_name (from auth user).
String _resolvedName(Map<String, dynamic> c) {
  final dn = c['display_name'] as String? ?? '';
  if (dn.isNotEmpty) return dn;
  return c['resolved_display_name'] as String? ?? '—';
}

// Format account label for autocomplete
String accountLabel(Map<String, dynamic> a, Map<String, String> customerNames) {
  final nickname = a['nickname'] as String? ?? '';
  final id = (a['id'] as String?)?.substring(0, 8) ?? '';
  final type = a['account_type'] as String? ?? '';
  final customerId = a['customer_id'] as String?;
  final customer = customerId != null ? (customerNames[customerId] ?? '') : '';
  final parts = <String>[];
  if (nickname.isNotEmpty) parts.add(nickname);
  if (customer.isNotEmpty) parts.add(customer);
  parts.add('$id · $type');
  return parts.join(' · ');
}

// Submit a posting to Ledger
Future<Map<String, dynamic>?> submitPosting(
  ETellerContext ctx, {
  required String instructionType,
  required String debitAccountId,
  required String creditAccountId,
  required String amountMinor,
  String denomination = 'CAD',
  String? description,
}) async {
  final batchId = 'eteller-${DateTime.now().millisecondsSinceEpoch}';
  final res = await ctx.services!.ledger.post('/v1/postings', body: {
    'batch_id': batchId,
    'instructions': [{
      'instruction_type': instructionType,
      'debit_account': debitAccountId,
      'credit_account': creditAccountId,
      'amount': amountMinor,
      'denomination': denomination,
      if (description != null) 'description': description,
    }],
  });
  if (res.isSuccess) {
    final entry = {
      'batch_id': batchId,
      'type': instructionType,
      'amount': amountMinor,
      'denomination': denomination,
      'description': description ?? '',
      'timestamp': DateTime.now().toIso8601String(),
    };
    ctx.logTransaction(entry);
    return res.data;
  }
  return null;
}

// Convert major units to minor units string
String toMinorUnits(String majorAmount) {
  final major = double.tryParse(majorAmount);
  if (major == null || major <= 0) return '0';
  return (major * 100).round().toString();
}

// Money input formatter regex
final moneyInputRegex = RegExp(r'^\d*\.?\d{0,2}');