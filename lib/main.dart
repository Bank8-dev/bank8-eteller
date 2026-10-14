// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:ETeller
// SPDX-License-Identifier: Apache-2.0

// eTeller — main entry point
// Branch teller terminal for Sentin8 platform.
//
// Bootstrap flow (same pattern as eBank):
// 1. App starts → GET /v1/app/runtime/context (via TLS headers)
// 2. Receives AppRuntimeContext { bffDomain, authDomain, branding }
// 3. Initializes AuthProvider with BFF base URL
// 4. Checks BFF /auth/session for existing session
// 5. Renders signed-in teller shell or sign-in redirect

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
// ignore: avoid_web_library_in_flutter
import 'package:web/web.dart' as web;
import 'theme.dart';
import 'app_context.dart';
import 'bootstrap.dart';
import 'test_bridge.dart';
import 'pages/pages.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Enable semantics for e2e/Playwright ARIA access (per memory notes)
  SemanticsBinding.instance.ensureSemantics();
  // F-D — register the e2e test bridge (window.sentin8TestSignOut). The
  // handler is wired to the AuthProvider when ETellerShell receives its
  // context; before that the bridge is a no-op.
  registerTestBridge();
  runApp(const ETellerApp());
}

class ETellerApp extends StatefulWidget {
  const ETellerApp({super.key});

  @override
  State<ETellerApp> createState() => _ETellerAppState();
}

class _ETellerAppState extends State<ETellerApp> {
  AppRuntimeContext? _runtimeContext;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      // Use the app's own origin so the TLS proxy injects the correct
      // X-Sentin8-Hostname header for runtime context resolution.
      final appBaseUrl = web.window.location.origin;
      final ctx = await fetchRuntimeContext(appBaseUrl: appBaseUrl);
      if (mounted) setState(() => _runtimeContext = ctx);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _runtimeContext?.displayName ?? 'eTeller',
      theme: _runtimeContext != null
          ? sentin8ThemeForContext(_runtimeContext!)
          : sentin8Theme(),
      debugShowCheckedModeBanner: false,
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_error != null) {
      return Scaffold(body: Center(child: Text('Bootstrap error: $_error')));
    }
    if (_runtimeContext == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ETellerContextProvider(
      runtimeContext: _runtimeContext!,
      child: const ETellerShell(),
    );
  }
}