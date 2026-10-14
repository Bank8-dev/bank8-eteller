// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:ETeller
// SPDX-License-Identifier: Apache-2.0

// eTeller auth provider — re-exported from sentin8.
//
// AuthProvider and ETellerUser are re-exported as aliases for
// BffAuthProvider and AppUser for backward compatibility.
export 'package:sentin8/sentin8.dart'
    show BffAuthProvider, AuthState, AppUser;

import 'package:sentin8/sentin8.dart';

/// Backward-compatible alias.
typedef AuthProvider = BffAuthProvider;

/// Backward-compatible alias.
typedef ETellerUser = AppUser;