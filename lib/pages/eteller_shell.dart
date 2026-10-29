// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:ETeller
// SPDX-License-Identifier: Apache-2.0

// eTeller shell - main app scaffold with left-rail navigation + content area.
//
// Mirrors the eBank / eFintech shell pattern (design/sentin8-design-system.md
// §7): a 240px custom sidebar with org logo, nav list, and a pinned user
// menu (avatar + sign-out). Replaces the previous Material `NavigationRail`
// so all three App store apps share the same visual language.

import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'package:web/web.dart' as web;
import '../theme.dart';
import '../app_context.dart';
import '../bff_ws.dart';
import '../test_bridge.dart';
import '../url_router.dart';
import 'dashboard_page.dart';
import 'customer_search_page.dart';
import 'customer_detail_page.dart';
import 'customer_onboarding_page.dart';
import 'shift_summary_page.dart';
import 'delegation_choice_page.dart';
import 'cash_deposit_page.dart';
import 'cheque_deposit_page.dart';
import 'pending_cheques_page.dart';
import 'withdrawal_page.dart';
import 'transfer_page.dart';
import 'account_opening_page.dart';
import 'account_management_page.dart';
import 'manual_decisions_page.dart';
import 'approval_tasks_page.dart';
import 'dlq_page.dart';
import 'posting_batches_page.dart';

class ETellerShell extends StatefulWidget {
  const ETellerShell({super.key});
  @override
  State<ETellerShell> createState() => _ETellerShellState();
}

class _ETellerShellState extends State<ETellerShell> {
  String _currentRoute = '/';
  ETellerContext? _cachedContext;
  // Customer-related menu items appear only after delegation.
  bool _hasDelegation = false;
  String? _delegationCustomerId;
  /// §4.3f (Option A) - the active CIBA delegation session id (from BFF
  /// POST /delegate/start). Set when the customer approves; cleared on
  /// expiry/revoke. Drives the customer-scoped service registry.
  String? _delegationId;
  String? _delegationCustomerName;
  String? _delegationCustomerEmail;
  String _pollingStatus = 'pending';
  // BFF WebSocket client for real-time delegation updates.
  BffWebSocket? _ws;
  // §3.0.3a - session-storage keys for delegation state restoration after a
  // full page reload (assisted-login round-trip navigates away and back).
  static const _ssDelegationId = 'eteller.delegation_id';
  static const _ssDelegationCustomerId = 'eteller.delegation_customer_id';
  static const _ssDelegationCustomerName = 'eteller.delegation_customer_name';
  static const _ssDelegationCustomerEmail = 'eteller.delegation_customer_email';
  bool _restoringDelegation = false;

  @override
  void initState() {
    super.initState();
    _currentRoute = currentRoute();
    if (kIsWeb) {
      web.window.onPopState.listen((_) {
        if (mounted) setState(() { _currentRoute = currentRoute(); });
      });
    }
  }

  @override
  void dispose() {
    _cachedContext?.auth.removeListener(_onAuthChanged);
    _ws?.disconnect();
    super.dispose();
  }

  void _connectWebSocket(ETellerContext ctx) {
    if (_ws != null) return; // Already connected.
    _ws = BffWebSocket(bffBaseUrl: ctx.runtimeContext.bffBaseUrl);
    _ws!.onDelegationResult = (msg) {
      final status = msg['status'] as String? ?? '';
      if (status == 'approved' && mounted) {
        _onDelegationApproved();
      } else if ((status == 'denied' || status == 'expired') && mounted) {
        setState(() => _pollingStatus = status);
      }
    };
    _ws!.onDelegationExpired = (_) {
      if (mounted) _clearDelegation();
    };
    // Live notification - show a snackbar.
    _ws!.onNotification = (msg) {
      if (!mounted) return;
      final title = msg['title'] as String? ?? 'Notification';
      final body = msg['body'] as String? ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title: $body'), duration: const Duration(seconds: 4)),
      );
    };
    // Account updates - refresh the current page if relevant.
    _ws!.onAccountUpdate = (msg) {
      if (!mounted) return;
      // Pages can listen to this via a change notifier or just refresh.
      // For now, log it; pages will subscribe to specific resource IDs.
      debugPrint('WS: account update - ${msg['resource_id'] ?? msg['account_id']}');
    };
    // Payment status changes.
    _ws!.onPaymentStatusChanged = (msg) {
      if (!mounted) return;
      final status = msg['status'] as String? ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment status: $status'), duration: const Duration(seconds: 3)),
      );
    };
    _ws!.connect();
  }

  void _navigate(String route) {
    setState(() => _currentRoute = route);
    navigateTo(route);
  }

  /// Called when customer search finds a customer - shows the delegation choice.
  void _startDelegation(String customerId, String customerName, String customerEmail) {
    setState(() {
      _delegationCustomerId = customerId;
      _delegationCustomerName = customerName;
      _delegationCustomerEmail = customerEmail;
      _delegationId = null;
      _currentRoute = '/delegation-choice';
    });
    navigateTo('/delegation-choice');
  }

  /// Called when delegation is approved - reveals customer operation menu items.
  /// §4.3f (Option A): rebuilds the service registry as customer-scoped  - 
  /// every ledger/payments call now carries `X-BFF-Delegation` so the BFF
  /// attaches the customer-approved delegated token. No standing staff
  /// scope is involved.
  void _onDelegationApproved() {
    final ctx = _cachedContext;
    if (ctx != null && _delegationId != null) {
      ctx.setActiveDelegation(_delegationId!);
    }
    _persistDelegation();
    setState(() {
      _hasDelegation = true;
      _currentRoute = '/customer-detail';
    });
    navigateTo('/customer-detail');
  }

  // ── §3.0.3a - delegation session persistence (sessionStorage) ──────────

  void _persistDelegation() {
    if (!kIsWeb) return;
    final ss = web.window.sessionStorage;
    if (_delegationId != null) ss.setItem(_ssDelegationId, _delegationId!);
    if (_delegationCustomerId != null) {
      ss.setItem(_ssDelegationCustomerId, _delegationCustomerId!);
    }
    if (_delegationCustomerName != null) {
      ss.setItem(_ssDelegationCustomerName, _delegationCustomerName!);
    }
    if (_delegationCustomerEmail != null) {
      ss.setItem(_ssDelegationCustomerEmail, _delegationCustomerEmail!);
    }
  }

  void _clearPersistedDelegation() {
    if (!kIsWeb) return;
    final ss = web.window.sessionStorage;
    ss.removeItem(_ssDelegationId);
    ss.removeItem(_ssDelegationCustomerId);
    ss.removeItem(_ssDelegationCustomerName);
    ss.removeItem(_ssDelegationCustomerEmail);
  }

  /// Restore a previously-approved delegation after a full page reload.
  /// Revalidates against BFF `GET /delegate/status`: the delegated token is
  /// minted by the BFF's background poller ~1 poll-interval (5s) AFTER the
  /// customer approves - which may be seconds AFTER this shell reloaded
  /// (the teller tab sits on the landing page while the customer authorizes
  /// in another tab). A single miss therefore means "not yet approved", so
  /// revalidate briefly (4 × 1s) before giving up; only a persistent
  /// has_token=false drops the persisted state (expired/unknown id).
  /// The delegation token itself never touches client storage - only the id.
  Future<void> _restoreDelegation(ETellerContext ctx) async {
    if (!kIsWeb || _restoringDelegation || _hasDelegation) return;
    _restoringDelegation = true;
    try {
      final ss = web.window.sessionStorage;
      final id = ss.getItem(_ssDelegationId);
      final custId = ss.getItem(_ssDelegationCustomerId);
      if (id == null || id.isEmpty || custId == null || custId.isEmpty) return;
      // Revalidate with short retries: between "start" and "approved" the
      // token legitimately does not exist yet - a single miss must not drop
      // the entry (the assisted-login round-trip reloads the app seconds
      // before the approval lands).
      bool? alive;
      // Retry for up to 8s: the BFF's background CIBA poller mints the
      // delegated token at its 5s interval AFTER the customer approves, so
      // the first status polls legitimately see has_token=false. The window
      // must span at least one poll interval beyond the approval.
      for (int attempt = 0; attempt < 8; attempt++) {
        alive = await _delegateStatus(ctx, id);
        if (alive == true) break;
        await Future.delayed(const Duration(seconds: 1));
      }
      if (alive == null) {
        // BFF unreachable - keep the storage entry, retry on next boot.
        return;
      }
      if (alive != true) {
        // Definitively dead (all retries exhausted): drop the entry.
        _clearPersistedDelegation();
        return;
      }
      if (!mounted) return;
      setState(() {
        _delegationId = id;
        _delegationCustomerId = custId;
        _delegationCustomerName =
            ss.getItem(_ssDelegationCustomerName);
        _delegationCustomerEmail =
            ss.getItem(_ssDelegationCustomerEmail);
        _hasDelegation = true;
      });
      ctx.setActiveDelegation(id);
      // Land on the customer detail page so the teller continues serving
      // the delegated customer (same post-approval landing as live flow).
      if (_currentRoute == '/') {
        setState(() => _currentRoute = '/customer-detail');
        navigateTo('/customer-detail');
      }
    } finally {
      _restoringDelegation = false;
    }
  }

  /// BFF `GET /delegate/status?delegation_id=...` - true when a live
  /// delegation token exists for [delegationId]. Addressed at the BFF root
  /// (not /proxy/*) - the delegate routes are BFF-own endpoints.
  Future<bool?> _delegateStatus(ETellerContext ctx, String delegationId) async {
    try {
      final base = ctx.runtimeContext.bffBaseUrl.replaceAll(RegExp(r'/+$'), '');
      final url = '$base/delegate/status?delegation_id=$delegationId';
      final response = await web.window.fetch(
        url.toJS,
        web.RequestInit(
          method: 'GET',
          credentials: 'include',
          headers: web.Headers()..set('Accept', 'application/json'),
        ),
      ).toDart;
      if (response.status != 200) return null;
      final body = jsonDecode((await response.text().toDart).toDart)
          as Map<String, dynamic>;
      return body['has_token'] == true;
    } catch (_) {
      return null;
    }
  }

  /// Called when delegation expires or is revoked - hides customer menu items.
  void _clearDelegation() {
    // §4.3f (Option A): drop the customer-scoped service registry so no
    // further customer-data calls go out under an expired delegation.
    _cachedContext?.clearActiveDelegation();
    _clearPersistedDelegation();
    setState(() {
      _hasDelegation = false;
      _delegationCustomerId = null;
      _delegationId = null;
      _delegationCustomerName = null;
      _delegationCustomerEmail = null;
      _currentRoute = '/';
    });
    navigateTo('/');
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ctx = ETellerContextProvider.of(context);

    if (ctx == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Cache context and listen to auth state changes (add listener only once).
    if (_cachedContext != ctx) {
      _cachedContext?.auth.removeListener(_onAuthChanged);
      _cachedContext = ctx;
      ctx.auth.addListener(_onAuthChanged);
      // Dashboard quick-action tiles route through this hook so they behave
      // exactly like the sidebar items (delegation guard included).
      ctx.navigate = _navigate;
      // §3.0.3a - restore a persisted delegation after a full reload so the
      // teller keeps serving the customer they delegated (assisted-login
      // round-trip). Fire-and-forget; _hasDelegation updates when revalidated.
      _restoreDelegation(ctx);
      // F-D - wire the e2e sign-out bridge to the real AuthProvider
      // sign-out path (same as clicking the user menu → Sign Out). The
      // bridge function itself is registered in main(); without this
      // handler it is a silent no-op and e2e tests cannot clear the BFF
      // session cookie between tests.
      setSignOutBridgeHandler(() {
        ctx.auth.signOut();
      });
    }

    // Avoid sign-in button flicker while the BFF /auth/session call is
    // still in flight - same guard as eBank's shell.
    if (!ctx.auth.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!ctx.auth.isSignedIn) {
      return _SignInScreen(auth: ctx.auth, runtimeContext: ctx.runtimeContext);
    }

    // Connect the WebSocket for real-time delegation updates.
    _connectWebSocket(ctx);

    final isAdmin = _isAdmin(ctx);

    Widget content;
    switch (_currentRoute) {
      case '/':
        content = const DashboardPage();
        break;
      case '/customer-search':
        content = CustomerSearchPage(onCustomerSelected: _startDelegation);
        break;
      case '/delegation-choice':
        if (_delegationCustomerId != null) {
          content = DelegationChoicePage(
            customerId: _delegationCustomerId!,
            customerName: _delegationCustomerName ?? '',
            customerEmail: _delegationCustomerEmail ?? '',
            onApproved: _onDelegationApproved,
            onDelegationId: (id) => setState(() {
                  _delegationId = id;
                  // §3.0.3a - persist the pending delegation id immediately:
                  // the approval round-trip (customer consent page) may reload
                  // this app before the SSE 'approved' event is consumed, so
                  // the id must survive in sessionStorage regardless of which
                  // tab/process observes the approval.
                  _persistDelegation();
                }),
          );
        } else {
          content = const DashboardPage();
        }
        break;
      case '/onboard-customer':
        content = const CustomerOnboardingPage();
        break;
      case '/shift-summary':
        content = const ShiftSummaryPage();
        break;
      // Customer operations - only accessible with delegation token.
      case '/cash-deposit':
        content = _hasDelegation ? const CashDepositPage() : _needDelegation();
        break;
      case '/cheque-deposit':
        content = _hasDelegation ? const ChequeDepositPage() : _needDelegation();
        break;
      case '/pending-cheques':
        content = _hasDelegation ? const PendingChequesPage() : _needDelegation();
        break;
      case '/withdrawal':
        content = _hasDelegation ? const WithdrawalPage() : _needDelegation();
        break;
      case '/transfer':
        content = _hasDelegation ? const TransferPage() : _needDelegation();
        break;
      case '/open-account':
        content = _hasDelegation ? const AccountOpeningPage() : _needDelegation();
        break;
      case '/account-mgmt':
        content = (_hasDelegation && isAdmin)
            ? const AccountManagementPage()
            : _needDelegation();
        break;
      case '/decisions':
        content = (_hasDelegation && isAdmin)
            ? const ManualDecisionsPage()
            : _needDelegation();
        break;
      case '/tasks':
        content = (_hasDelegation && isAdmin)
            ? const ApprovalTasksPage()
            : _needDelegation();
        break;
      // Ops review surfaces (ETA set 1) - reachable under the delegation
      // window like the other customer-operation pages.
      case '/dlq':
        content = _hasDelegation ? const DlqPage() : _needDelegation();
        break;
      case '/posting-batches':
        content = _hasDelegation ? const PostingBatchesPage() : _needDelegation();
        break;
      case '/customer-detail':
        // Post-approval landing (set by _onDelegationApproved): the teller
        // continues serving the delegated customer. Requires the delegation
        // customer id AND a rebuilt service registry (§3.1.3 - during the
        // restore window `ctx.services` is still null; fall back to Dashboard
        // so the shell never renders a page that assumes it).
        content = (_hasDelegation &&
                _delegationCustomerId != null &&
                _cachedContext?.services != null)
            ? CustomerDetailPage(customerId: _delegationCustomerId!)
            : const DashboardPage();
        break;
      default:
        content = const DashboardPage();
    }

    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(ctx, isAdmin),
          const VerticalDivider(width: 1, color: Sentin8Colors.border),
          Expanded(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height,
                ),
                child: content,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(ETellerContext ctx, bool isAdmin) {
    final appName = ctx.runtimeContext.displayName;
    final logoUrl = (ctx.runtimeContext.logoIconUrl ?? '').isNotEmpty
        ? ctx.runtimeContext.logoIconUrl!
        : (ctx.runtimeContext.logoUrl ?? '');
    return Container(
      width: 240,
      color: Sentin8Colors.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(Sentin8Spacing.lg),
            child: Row(
              children: [
                if (logoUrl.isNotEmpty)
                  networkLogo(
                    logoUrl,
                    size: 28,
                    fallbackWidget: const Icon(Icons.point_of_sale,
                        color: Sentin8Colors.primary, size: 28),
                  )
                else
                  const Icon(Icons.point_of_sale,
                      color: Sentin8Colors.primary, size: 28),
                const SizedBox(width: Sentin8Spacing.sm),
                Expanded(
                  child: Text(appName,
                      style: Sentin8Text.headlineMedium,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          const Divider(),
          // Nav list scrolls if it overflows the viewport; the user
          // menu below stays pinned to the bottom.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // ── Base operations (always available, staff token) ──
                  _NavItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    route: '/',
                    current: _currentRoute,
                    onTap: _navigate,
                  ),
                  _NavItem(
                    icon: Icons.person_search_outlined,
                    label: 'Customer Search',
                    route: '/customer-search',
                    current: _currentRoute,
                    onTap: _navigate,
                  ),
                  _NavItem(
                    icon: Icons.person_add_outlined,
                    label: 'Onboard Customer',
                    route: '/onboard-customer',
                    current: _currentRoute,
                    onTap: _navigate,
                  ),
                  _NavItem(
                    icon: Icons.assessment_outlined,
                    label: 'Shift Summary',
                    route: '/shift-summary',
                    current: _currentRoute,
                    onTap: _navigate,
                  ),
                  // ── Customer operations (only after delegation) ──
                  if (_hasDelegation) ...[
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Sentin8Spacing.md,
                        vertical: Sentin8Spacing.xs,
                      ),
                      child: Text(
                        'Customer: ${_delegationCustomerName ?? ""}',
                        style: Sentin8Text.labelSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _NavItem(
                      icon: Icons.payments_outlined,
                      label: 'Cash Deposit',
                      route: '/cash-deposit',
                      current: _currentRoute,
                      onTap: _navigate,
                    ),
                    _NavItem(
                      icon: Icons.receipt_long_outlined,
                      label: 'Cheque Deposit',
                      route: '/cheque-deposit',
                      current: _currentRoute,
                      onTap: _navigate,
                    ),
                    _NavItem(
                      icon: Icons.pending_actions_outlined,
                      label: 'Pending Cheques',
                      route: '/pending-cheques',
                      current: _currentRoute,
                      onTap: _navigate,
                    ),
                    _NavItem(
                      icon: Icons.atm_outlined,
                      label: 'Withdrawal',
                      route: '/withdrawal',
                      current: _currentRoute,
                      onTap: _navigate,
                    ),
                    _NavItem(
                      icon: Icons.swap_horiz,
                      label: 'Transfer',
                      route: '/transfer',
                      current: _currentRoute,
                      onTap: _navigate,
                    ),
                    _NavItem(
                      icon: Icons.account_balance_outlined,
                      label: 'Open Account',
                      route: '/open-account',
                      current: _currentRoute,
                      onTap: _navigate,
                    ),
                    if (isAdmin) ...[
                      _NavItem(
                        icon: Icons.manage_accounts_outlined,
                        label: 'Account Mgmt',
                        route: '/account-mgmt',
                        current: _currentRoute,
                        onTap: _navigate,
                      ),
                      _NavItem(
                        icon: Icons.gavel_outlined,
                        label: 'Decisions',
                        route: '/decisions',
                        current: _currentRoute,
                        onTap: _navigate,
                      ),
                      _NavItem(
                        icon: Icons.assignment_turned_in_outlined,
                        label: 'Tasks',
                        route: '/tasks',
                        current: _currentRoute,
                        onTap: _navigate,
                      ),
                    ],
                    const Divider(),
                    _NavItem(
                      icon: Icons.lock_open_outlined,
                      label: 'End Customer Session',
                      route: '/',
                      current: _currentRoute,
                      onTap: (_) => _clearDelegation(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(),
          _UserMenu(appContext: ctx),
        ],
      ),
    );
  }

  /// Shown when a customer operation is accessed without a delegation token.
  Widget _needDelegation() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 48, color: Sentin8Colors.primary),
          const SizedBox(height: Sentin8Spacing.lg),
          const Text(
            'Customer access required',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: Sentin8Spacing.sm),
          const Text(
            'Search for a customer and request access to perform this operation.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Sentin8Spacing.lg),
          FilledButton(
            onPressed: () => _navigate('/customer-search'),
            child: const Text('Search for Customer'),
          ),
        ],
      ),
    );
  }

  /// eTeller admin surfaces (account management, manual decisions, approval
  /// tasks) are gated by the app-declared `eteller:admin` role-marker scope.
  /// That scope is granted exclusively to members of the `eteller-admin`
  /// group, which App provisions in the org-scoped Auth when the listing
  /// is installed (see design/sentin8-app-eteller-app-technical-design.md
  /// §14.4). Exact match - a substring match would false-positive on
  /// `payments:manual_decisions:read` held by every teller.
  ///
  /// Per SDK8 §3.9, server enforcement is mandatory - this client guard
  /// only hides UI affordances.
  bool _isAdmin(ETellerContext ctx) {
    return ctx.auth.state.scopes.contains('eteller:admin');
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final String current;
  final ValueChanged<String> onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = current == route;
    return ListTile(
      leading: Icon(icon,
          color: isActive ? Sentin8Colors.primary : Sentin8Colors.textSecondary),
      title: Text(
        label,
        style: TextStyle(
          color:
              isActive ? Sentin8Colors.primary : Sentin8Colors.textPrimary,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      selected: isActive,
      selectedTileColor: Sentin8Colors.primary.withValues(alpha: 0.08),
      onTap: () => onTap(route),
    );
  }
}

class _UserMenu extends StatelessWidget {
  final ETellerContext appContext;

  const _UserMenu({required this.appContext});

  @override
  Widget build(BuildContext context) {
    final user = appContext.auth.user;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Sentin8Colors.primary,
        child: Text(
          user?.displayName?.isNotEmpty == true
              ? user!.displayName![0].toUpperCase()
              : user?.email.isNotEmpty == true
                  ? user!.email[0].toUpperCase()
                  : '?',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(user?.displayName ?? user?.email ?? 'User',
          style: Sentin8Text.bodyMedium),
      trailing: IconButton(
        icon: const Icon(Icons.logout, color: Sentin8Colors.textSecondary),
        onPressed: () => appContext.auth.signOut(),
        tooltip: 'Sign Out',
      ),
    );
  }
}

class _SignInScreen extends StatelessWidget {
  final dynamic auth;
  final dynamic runtimeContext;
  const _SignInScreen({this.auth, this.runtimeContext});

  @override
  Widget build(BuildContext context) {
    final appName = runtimeContext?.displayName ?? 'eTeller';
    final logoUrl = (runtimeContext?.logoIconUrl as String?)?.isNotEmpty == true
        ? runtimeContext!.logoIconUrl as String
        : (runtimeContext?.logoUrl as String?) ?? '';
    return Scaffold(
      backgroundColor: Sentin8Colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: GlassPanel(
              padding: const EdgeInsets.all(Sentin8Spacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (logoUrl.isNotEmpty)
                      networkLogo(
                        logoUrl,
                        size: 64,
                        fallbackWidget: const Icon(Icons.point_of_sale,
                            size: 64, color: Sentin8Colors.primary),
                      )
                    else
                      const Icon(Icons.point_of_sale,
                          size: 64, color: Sentin8Colors.primary),
                    const SizedBox(height: Sentin8Spacing.lg),
                    Text('Welcome to $appName', style: Sentin8Text.headlineLarge),
                    const SizedBox(height: Sentin8Spacing.sm),
                    const Text('Branch Teller Terminal',
                        style: Sentin8Text.bodyLarge,
                        textAlign: TextAlign.center),
                    const SizedBox(height: Sentin8Spacing.xl),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => auth?.signInWithAuth(),
                        icon: const Icon(Icons.badge),
                        label: const Text('Staff Sign In'),
                      ),
                    ),
                    const SizedBox(height: Sentin8Spacing.sm),
                    const Text('Staff access only - no customer sign-up',
                        style: Sentin8Text.labelSmall,
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccessDeniedPage extends StatelessWidget {
  const _AccessDeniedPage();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 48, color: Sentin8Colors.error),
            SizedBox(height: Sentin8Spacing.md),
            Text('Access Denied', style: Sentin8Text.headlineMedium),
            SizedBox(height: Sentin8Spacing.sm),
            Text('You do not have permission to access this page.',
                style: Sentin8Text.bodyMedium),
          ],
        ),
      ),
    );
  }
}