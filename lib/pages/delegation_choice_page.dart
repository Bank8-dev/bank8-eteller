// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:ETeller
// SPDX-License-Identifier: Apache-2.0

// eTeller - Delegation Choice Page.
//
// After customer search finds a customer, this page presents two options:
// - CIBA (decoupled device - customer approves on authenticator)
// - Assisted Login (front-channel link - customer authenticates in browser)
//
// The selected flow is sent to BFF POST /delegate/start (BFF's own endpoint,
// not a proxied call).
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import '../theme.dart';
import '../app_context.dart';

class DelegationChoicePage extends StatefulWidget {
  final String customerId;
  final String customerName;
  final String customerEmail;
  final VoidCallback? onApproved;
  /// §4.3f (Option A) - reports the BFF delegation session id as soon as
  /// POST /delegate/start returns, so the shell can attach it to the
  /// customer-scoped service registry on approval.
  final ValueChanged<String>? onDelegationId;

  const DelegationChoicePage({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    this.onApproved,
    this.onDelegationId,
  });

  @override
  State<DelegationChoicePage> createState() => _DelegationChoicePageState();
}

class _DelegationChoicePageState extends State<DelegationChoicePage> {
  bool _isLoading = false;
  bool _polling = false;
  String _pollStatus = 'pending';
  String? _error;
  String? _verificationUriComplete;
  String? _shortCode;
  String? _delegationId;

  void _copyToClipboard(String text) {
    try {
      web.window.navigator.clipboard.writeText(text);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied to clipboard'), duration: Duration(seconds: 2)),
      );
    } catch (e) {
      debugPrint('Clipboard API failed: $e');
    }
  }

  Future<Map<String, dynamic>> _postBff(String path, Map<String, dynamic> body) async {
    final ctx = ETellerContextProvider.of(context)!;
    final base = ctx.runtimeContext.bffBaseUrl;
    final url = '$base$path';
    final response = await web.window.fetch(
      url.toJS,
      web.RequestInit(
        method: 'POST',
        credentials: 'include',
        headers: web.Headers()..set('Accept', 'application/json')..set('Content-Type', 'application/json'),
        body: jsonEncode(body).toJS,
      ),
    ).toDart;
    final text = (await response.text().toDart).toDart;
    if (response.status >= 400) {
      throw Exception('BFF $path returned ${response.status}: $text');
    }
    return jsonDecode(text) as Map<String, dynamic>;
  }

  Future<void> _startDelegation(String flow) async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await _postBff('/delegate/start', {
        'customer_id': widget.customerId,
        'flow': flow,
        'scope': 'openid bank8:ledger:accounts:read bank8:ledger:accounts:write bank8:ledger:postings:read bank8:ledger:postings:write bank8:ledger:balances:read bank8:ledger:customers:read bank8:payments:instructions:read bank8:payments:instructions:write',
        'binding_message': 'eTeller: Customer access for ${widget.customerName}',
        'login_hint': widget.customerEmail,
        'reason': 'teller session',
      });
      setState(() {
        _delegationId = res['delegation_id'] as String?;
        _verificationUriComplete = res['verification_uri_complete'] as String?;
        _shortCode = res['short_code'] as String?;
        _polling = true;
        _pollStatus = 'pending';
      });
      if (_delegationId != null) {
        widget.onDelegationId?.call(_delegationId!);
        _poll(_delegationId!);
      }
    } catch (e) {
      setState(() => _error = 'Failed to start: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _poll(String delegationId) async {
    for (int i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;
      try {
        final res = await _postBff('/delegate/poll', {'delegation_id': delegationId});
        final status = res['status'] as String? ?? 'pending';
        setState(() => _pollStatus = status);
        if (status == 'approved') {
          setState(() => _polling = false);
          if (widget.onApproved != null) widget.onApproved!();
          return;
        }
        if (status == 'denied' || status == 'expired') {
          setState(() => _polling = false);
          return;
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() { _polling = false; _pollStatus = 'expired'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer Access')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(Sentin8Spacing.xl),
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_polling || _pollStatus == 'approved') {
      return _buildPollingView();
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.verified_user, size: 48, color: Sentin8Colors.primary),
        const SizedBox(height: Sentin8Spacing.lg),
        Text('Request customer access for:', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
        const SizedBox(height: Sentin8Spacing.sm),
        Text(widget.customerName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        const SizedBox(height: Sentin8Spacing.xl),
        Text('Choose how the customer should authorize access:', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
        const SizedBox(height: Sentin8Spacing.lg),
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
          const SizedBox(height: Sentin8Spacing.md),
        ],
        FilledButton.icon(
          onPressed: _isLoading ? null : () => _startDelegation('ciba'),
          icon: const Icon(Icons.phone_android),
          label: const Text('CIBA - Customer approves on device'),
        ),
        const SizedBox(height: Sentin8Spacing.md),
        FilledButton.icon(
          onPressed: _isLoading ? null : () => _startDelegation('assisted_login'),
          icon: const Icon(Icons.link),
          label: const Text('Assisted Login - Send link to customer'),
        ),
        if (_isLoading) ...[
          const SizedBox(height: Sentin8Spacing.md),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }

  Widget _buildPollingView() {
    if (_pollStatus == 'approved') {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 48, color: Colors.green),
          const SizedBox(height: Sentin8Spacing.lg),
          const Text('Customer access granted!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        ],
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: Sentin8Spacing.lg),
        Text(
          _pollStatus == 'denied'
              ? 'Customer denied access'
              : _pollStatus == 'expired'
                  ? 'Request expired'
                  : 'Waiting for customer approval...',
          textAlign: TextAlign.center,
        ),
        if (_verificationUriComplete != null) ...[
          const SizedBox(height: Sentin8Spacing.md),
          Text('Link: $_verificationUriComplete', style: TextStyle(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center),
          const SizedBox(height: Sentin8Spacing.sm),
          OutlinedButton.icon(
            onPressed: () => _copyToClipboard(_verificationUriComplete!),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy Link'),
          ),
        ],
        if (_shortCode != null) ...[
          const SizedBox(height: Sentin8Spacing.sm),
          Text('Reference code: $_shortCode', style: TextStyle(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center),
        ],
      ],
    );
  }
}