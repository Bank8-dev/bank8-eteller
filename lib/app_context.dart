// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:ETeller
// SPDX-License-Identifier: Apache-2.0

// eTeller app context - central runtime state
// Ties together runtime context, auth, services, and internal account resolver

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'bootstrap.dart';
import 'auth_provider.dart';
import 'services.dart';
import 'internal_accounts.dart';

class ETellerContext extends ChangeNotifier {
  final AppRuntimeContext runtimeContext;
  final AuthProvider auth;
  ETellerServices? services;
  InternalAccountResolver? internalAccounts;
  final String correlationId;
  List<Map<String, dynamic>> _sessionLog = [];

  ETellerContext._({
    required this.runtimeContext,
    required this.auth,
    required this.correlationId,
  }) {
    auth.addListener(_onAuthChanged);
    _updateServices();
  }

  static Future<ETellerContext> create(AppRuntimeContext runtimeContext) async {
    final corrId = generateCorrelationId();
    final auth = AuthProvider(
      bffBaseUrl: runtimeContext.bffBaseUrl,
      authDomain: runtimeContext.authDomain,
    );
    auth.onRedirect = (String url) {
      web.window.location.href = url;
    };
    await auth.init();
    final ctx = ETellerContext._(runtimeContext: runtimeContext, auth: auth, correlationId: corrId);
    if (auth.isSignedIn) {
      await ctx._loadInternalAccounts();
    }
    return ctx;
  }

  void _onAuthChanged() {
    _updateServices();
    if (auth.isSignedIn && internalAccounts == null) {
      _loadInternalAccounts();
    }
    notifyListeners();
  }

  void _updateServices() {
    services = ETellerServices(
      bffBaseUrl: runtimeContext.bffBaseUrl,
      csrfToken: auth.csrfToken,
      correlationId: correlationId,
    );
  }

  String? _activeDelegationId;

  /// The active CIBA delegation session id, if any (§4.3f Option A).
  String? get activeDelegationId => _activeDelegationId;

  /// §4.3f (Option A): rebuild the service registry as customer-scoped  - 
  /// every ledger/payments call carries `X-BFF-Delegation` so the BFF
  /// attaches the customer-approved delegated token instead of the staff
  /// session token.
  void setActiveDelegation(String delegationId) {
    _activeDelegationId = delegationId;
    services = ETellerServices.delegatedCustomer(
      bffBaseUrl: runtimeContext.bffBaseUrl,
      csrfToken: auth.csrfToken,
      correlationId: correlationId,
      delegationId: delegationId,
    );
    notifyListeners();
  }

  /// Drop the customer-scoped registry (delegation expired/revoked)  - 
  /// subsequent calls use the plain staff clients, which see no customer
  /// data (Option A: no standing staff scope).
  void clearActiveDelegation() {
    _activeDelegationId = null;
    _updateServices();
    notifyListeners();
  }

  Future<void> _loadInternalAccounts() async {
    internalAccounts = InternalAccountResolver(services!, runtimeEnvId: runtimeContext.environmentId);
    await internalAccounts!.load();
  }

  void logTransaction(Map<String, dynamic> entry) {
    _sessionLog.add(entry);
    notifyListeners();
  }

  List<Map<String, dynamic>> get sessionLog => List.unmodifiable(_sessionLog);

  /// Shell-provided navigation hook - the dashboard quick-action tiles use
  /// it to route through the same guarded path as the sidebar items.
  /// Set by ETellerShell on first build; null before that.
  void Function(String route)? navigate;

  @override
  void dispose() {
    auth.removeListener(_onAuthChanged);
    auth.dispose();
    super.dispose();
  }
}

class ETellerContextProvider extends StatefulWidget {
  final AppRuntimeContext runtimeContext;
  final Widget child;
  const ETellerContextProvider({super.key, required this.runtimeContext, required this.child});

  @override
  State<ETellerContextProvider> createState() => _ETellerContextProviderState();

  static ETellerContext? of(BuildContext context) {
    final inh = context.dependOnInheritedWidgetOfExactType<_ETellerContextInherited>();
    return inh?.ctx;
  }
}

class _ETellerContextProviderState extends State<ETellerContextProvider> {
  ETellerContext? _ctx;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final ctx = await ETellerContext.create(widget.runtimeContext);
    if (mounted) setState(() => _ctx = ctx);
  }

  @override
  void dispose() {
    _ctx?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ctx == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return _ETellerContextInherited(ctx: _ctx!, child: widget.child);
  }
}

class _ETellerContextInherited extends InheritedWidget {
  final ETellerContext ctx;
  const _ETellerContextInherited({required this.ctx, required super.child});
  @override
  bool updateShouldNotify(_ETellerContextInherited old) => ctx != old.ctx;
}