// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:ETeller
// SPDX-License-Identifier: Apache-2.0

// eTeller - Test bridge for e2e automation.
//
// E2e tests interact with the app ONLY through the UI - clicking
// buttons, typing into fields, and calling these test bridge functions
// which trigger the same Flutter widget code as clicking the UI control.
// No direct API/fetch calls are made from the test.
//
// Mirrors sentin8/apps/dash/lib/test_bridge.dart - e2e tests call
// window.sentin8TestSignOut() to sign out via the same code path as the
// SDK AuthProvider (BFF /auth/sign-out + local state clear). Without this
// bridge, signOutViaUI in the e2e harness is a silent no-op on eTeller
// pages and stale BFF session cookies persist across tests.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;

// Bridge handler for sentin8TestSignOut. Set by main() to call
// ETellerContext's AuthProvider.signOut(). Null by default so the bridge
// is a no-op until main() wires it up.
void Function()? _signOutBridgeHandler;

/// Set the sign-out bridge handler. Called by the shell once the
/// ETellerContext (and its AuthProvider) is available.
void setSignOutBridgeHandler(void Function()? handler) {
  _signOutBridgeHandler = handler;
}

void signOutViaBridge() {
  if (_signOutBridgeHandler != null) {
    _signOutBridgeHandler!();
  }
}

/// Called by the Flutter app in main() to expose the bridge on window.
void registerTestBridge() {
  final w = web.window as JSObject;

  // window.sentin8TestSignOut = function() { signOutViaBridge(); }
  w.setProperty(
    'sentin8TestSignOut'.toJS,
    (() {
      signOutViaBridge();
      return true;
    }).toJS,
  );
}