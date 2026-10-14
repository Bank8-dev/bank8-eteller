# README.md: Bank8:eTeller — Staff Teller Terminal App

> Third-party Sentin8:App application. It uses the Sentin8 Flutter SDK
> (`sdk/flutter/sentin8`) as a published package. For wire-level detail read
> `DESIGN.md`; for the business view read `BUSINESS.md`.

## 1. Summary

eTeller is the staff Flutter app of the Bank8 vertical: a branch teller
terminal for customer search/onboarding and **delegated** customer
operations — cash/cheque deposits, withdrawals, transfers, account
management, statement viewing, posting-batch review, DLQ and manual-decision
handling, and payment approval tasks. Customer-data operations ride a
CIBA-delegated, time-boxed customer token; the teller never holds customer
credentials.

## 2. Motivation

A teller does bank work *on behalf of* a customer standing at the counter —
but authorization systems speak the language of "who is allowed to do what
with whose account". The platform's answer is explicit, auditable delegation:
the teller picks the customer, the customer (or assisted link) approves the
operation remotely, and a short-lived delegated token whose `act` claim names
the teller executes the posting. eTeller is the counter surface for that
model, plus the operational cockpit (batches, DLQ, decisions, tasks) a branch
needs.

## 3. Architecture & High-Level Design

```mermaid
graph TD
    B[Teller browser] --> M[main.dart bootstrap]
    M --> RC[fetchRuntimeContext — own origin, fail-closed]
    M --> C[ETellerContext — inherited app state]
    C --> S[ETellerServices — staff + delegated client registries]

    subgraph Via Sentin8:BFF — session cookie, tokens server-side
        S -->|staffLedger — never delegated| LED[bank8-ledger — internal accounts]
        S -->|delegated — X-BFF-Delegation| LED2[bank8-ledger — customer postings]
        S --> PAY[bank8-payments — tasks + decisions]
        S --> DEL[BFF /delegate/* — CIBA lifecycle]
        S --> WS[BFF WebSocket — delegation updates]
    end
```

Components:

- **Bootstrap** — `fetchRuntimeContext()` (SDK) from own origin; failure
  is fatal, never degraded.
- **`ETellerContext`** (`app_context.dart`) — state holder adding the
  `InternalAccountResolver`, the client-side `sessionLog`, the active
  delegation setter, and the `navigate` callback.
- **`ETellerServices`** (`services.dart`) — `ledger`, `payments` clients plus
  a dedicated `staffLedger` client that is **never** delegation-stamped, and
  the `delegatedCustomer` factory that stamps `X-BFF-Delegation` on every
  customer-scoped call.
- **`InternalAccountResolver`** (`internal_accounts.dart`) — staff-scoped
  cache of internal account ids by nickname (cash, cheque clearing,
  liquidity, clearing, suspense) used as posting counterparties.
- **Delegation lifecycle** (`eteller_shell.dart`) — CIBA poll / assisted-link
  journeys via BFF `/delegate/*`, delegation state persisted in
  `sessionStorage` and revalidated after page reload; live updates ride the
  BFF WebSocket.
- **Pages** — teller journeys (see `DESIGN.md` §4 for the full route map).

## 4. Key Traits and Data Structures

- **Two scoped client registries:** `staffLedger` (staff token, internal
  plumbing only) vs the delegated customer registry (every request carries
  `X-BFF-Delegation: {delegationId}`; the BFF attaches the CIBA-delegated
  token whose `sub` is the customer and `act` the teller).
- **`InternalAccountResolver`**: nickname-keyed internal account lookup with
  an org-validated env override — internal accounts are counterparty
  plumbing invisible to holder tokens, so they resolve only via staff scope.
- **`sessionLog`**: a per-shift client-side log of teller operations that
  feeds the shift summary, the pending-cheque view, and receipts.
- **Delegation state shape:** `eteller.delegation_id` (+ companion keys) in
  `sessionStorage`, revalidated against the BFF status endpoint after any
  reload; dropped on expiry.
- **CIBA declaration** in the listing manifest (`ciba_defaults`: assisted
  link delivery, poll mode, bounded expiry, binding-message template, and
  the delegated customer scope subset).

## 5. Rationale, Trade-offs, and Alternatives

- **CIBA decoupled delegation, not password sharing or sub-sessions.** The
  customer approves on their own device (or via assisted link); the teller
  receives a time-boxed, `act`-attributed, audited token. Rejected: teller
  "operates as customer" via shared credentials (unattributable,
  unauditable, unsafe) and direct teller-token writes to customer accounts
  (breaks holder attribution).
- **Separate `staffLedger` client.** Internal accounts cannot be resolved
  with a delegated (holder) token — they carry no `customer_id` — so mixing
  them into the delegated registry guarantees failure or, worse, leakage
  attempts. A structurally separate client makes the invisible-to-holders
  rule executable. Rejected: one multiplexed registry with per-call flags.
- **Delegation state in `sessionStorage`, revalidated server-side.** A teller
  reloads the terminal mid-operation; the delegation must survive reload but
  only if the BFF still considers it valid. Client-side storage alone is
  untrusted; the restore loop revalidates against the BFF before any page
  uses it. Rejected: in-memory-only state (fragile) — and trust-on-reload
  (unsafe).
- **WebSocket (not SSE) for delegation updates.** Delegation approval is an
  interactive, bidirectional wait state on the terminal; the platform
  reserves WebSocket for the bidirectional tier, and this is one.
- **Counterparty model over free-form accounts.** Deposits/withdrawals pick
  internal accounts from the resolver by nickname — the teller cannot typo a
  GL account; teller-initiated transfers remain explicit.

## 6. Internal Implementation & Invariants (Private Design)

- **Routes** (shell switch): `/`, `/customer-search`, `/delegation-choice`,
  `/onboard-customer`, `/shift-summary`, `/cash-deposit`,
  `/cheque-deposit`, `/pending-cheques`, `/withdrawal`, `/transfer`,
  `/open-account`, `/account-mgmt`, `/decisions`, `/tasks`, `/dlq`,
  `/posting-batches`, `/customer-detail`. `url_router.dart` re-exports the
  SDK navigation helpers only.
- **Delegation restore loop:** on load, the shell revalidates the stored
  delegation against `GET /delegate/status?delegation_id=…` with bounded
  retries; failure clears the delegation and falls back to staff-only
  navigation.
- **Sign-out bridge** (`test_bridge.dart`): registers `window.sentin8TestSignOut`
  wired to the same `AuthProvider.signOut()` path the user menu uses, so E2E
  sign-out exercises the identical code path (Flutter-web semantics make the
  menu unreachable to Playwright otherwise).
- **Invariants:**
  - Exactly three operations are staff-token-only: customer search,
    onboarding, and the shift summary — everything touching customer data
    requires an active delegation.
  - The delegated registry is discarded the moment the delegation expires.
  - Internal accounts are never requested through the delegated client.
  - Every posting carries a `batch_id` and idempotency key; retries in the
    deposit/withdrawal flows reuse the same key.
  - No credential, token, or delegated token is ever serialized outside the
    BFF session; `sessionStorage` holds the delegation *id*, never tokens.

## 7. Unresolved Questions / Future Designs

- Cheque clearing settlement (mark cleared/bounced) currently concludes the
  journey client-side; wiring the settle step to the ledger cheque pipeline
  is the known functional gap.
- Teller cash-drawer balancing / end-of-day cash reconciliation is not yet
  designed (today the shift summary is derived from the client `sessionLog`
  only).

---

**Design attribution:** bank8:eteller and its underlying concepts were designed by Hamid Jahanzad <Hamid@Jahanzad.com>.
