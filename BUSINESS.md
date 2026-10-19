# Bank8:eTeller - Business Requirements & Functionality

> Audience: product owners, business analysts, and anyone evaluating what
> Bank8:eTeller **does for the business**. For architecture read `README.md`;
> for wire-level detail read `DESIGN.md`.

## 1. Business Purpose

- Give branch staff a single terminal for counter work: finding customers,
  onboarding them, and performing cash/cheque/posting operations **on the
  customer's behalf with the customer's explicit remote approval**.
- Make delegated banking safe by construction: time-boxed, attributable (`act`
  = teller), audited delegation instead of credential sharing.
- Provide the branch operations cockpit: posting batches, DLQ review,
  manual payment decisions, and approval tasks.

## 2. Business Scope (What the Service Provides)

| Capability | Delivered through |
|---|---|
| Customer search & detail | Bank8:Ledger |
| Customer onboarding | Bank8:Ledger |
| Delegation journeys (CIBA decoupled approval / assisted link) | Sentin8:BFF `/delegate/*` + Sentin8:Auth |
| Cash deposit / cheque deposit / withdrawal / transfer | Bank8:Ledger postings (delegated token) |
| Account opening and account management for walk-in customers | Bank8:Ledger |
| Printable receipts for counter transactions | client-side (posting receipt data) |
| Statement listing for a customer account | Bank8:Ledger + storage |
| Posting-batch review | Bank8:Ledger |
| DLQ review + republish (teller-visible ops surface) | Bank8:Ledger |
| Manual payment decisions review + submit | Bank8:Payments |
| Payment approval tasks | Bank8:Payments |
| Shift summary of teller activity | client session log |
| Pending-cheque tracking (cleared/bounced marks) | client session log (settlement wiring pending) |

**What eTeller does NOT own (business boundary):**

| Concern | Owning service |
|---|---|
| Identity, delegation approval UI | Sentin8:Auth / Sentin8:App hosted surfaces |
| Delegation gateway, delegated-token issuance | Sentin8:BFF |
| Financial truth (postings, balances, internal accounts) | Bank8:Ledger |
| Payment task/decision state machines | Bank8:Payments |
| Structured persistence | Sentin8:DB |
| Cheque image custody | storage |

## 3. Business Capabilities

| Area | Capability | Business rule |
|---|---|---|
| Counter identity | Customer search/onboarding | Staff may find and create customers; these are the only non-delegated customer-facing reads/writes. |
| Delegation | Customer-approved teller work | Every customer-data operation requires the customer's approval via CIBA (decoupled device or assisted link); approval is time-boxed (configurable expiry) and the binding message names the teller and the operation. |
| Cash handling | Cash deposit/withdrawal | Money moves through ledger postings against the branch's internal cash account; the teller picks the branch account from a controlled resolver, never types account numbers. |
| Cheque handling | Cheque deposit + pending tracking | Cheques post as authorized (inbound authorisation) against the cheque-clearing internal account; pending cheques are tracked until settlement concludes. |
| Transfers | Teller-initiated transfer | Counter transfers post as transfer instructions with idempotency keys. |
| Servicing | Account management + statements | Account status changes and statement listing operate on the delegated customer's accounts only. |
| Operations | Batches, DLQ, decisions, tasks | Staff review committed batches, land/replay DLQ entries, submit manual payment decisions, and act on approval tasks - all staff-authorize, all audited. |
| Shift control | Shift summary | The teller sees their own shift's operation counts; the shift summary is staff-only. |

## 4. Business Events (Outbound)

eTeller emits no domain events of its own; operations it triggers produce
upstream events in the owning services:

| Operation in app | Upstream event |
|---|---|
| Delegated posting (deposit/withdrawal/transfer) | Ledger posting committed (Bank8:Ledger) |
| Delegation start/approval | Delegation lifecycle events (Sentin8:Auth / BFF) |
| Manual decision submit / task action | Payments decision/task events (Bank8:Payments) |
| DLQ republish | Ledger DLQ replay (Bank8:Ledger) |
| Customer onboarding | Customer created (Bank8:Ledger) |

**Inbound (consumed):** delegation state updates over the BFF WebSocket
(approval, expiry); task/decision updates reflected on page refresh.

## 5. Business Rules & Invariants

1. The teller never holds customer credentials; all customer work is
   delegation-based and auditable with the teller as actor.
2. Delegations are time-boxed; an expired delegation silently disables
   customer operations (staff navigation remains).
3. Exactly three operations run on the staff token alone: customer search,
   customer onboarding, shift summary.
4. Internal bank accounts (cash, clearing, suspense, liquidity) are reachable
   only through the staff scope - never through delegated customer access.
5. Every posting is idempotent; teller retries cannot double-post.
6. Manual decisions and task actions are staff-authorize and audited; a
   decision can always be traced to the acting teller.
7. The terminal fails closed without a verified instance identity.
8. Receipts are rendered from posting result data - the app never invents
   financial figures.

## 6. Target-User Roles & Use Cases

| Persona | What they do |
|---|---|
| Branch teller | Searches/onboards customers, runs delegated deposits/withdrawals/transfers, prints receipts, tracks pending cheques, reviews their shift. |
| Branch operations staff | Reviews posting batches, lands DLQ entries, submits manual decisions, works approval tasks. |
| Customer (remote approver) | Approves or denies the teller's operation from their own device via the hosted approval journey. |
| Product owner | Measures counter throughput and delegated-operation safety. |

## 7. KPIs / Success Criteria

- **Reliability:** delegation restore after reload never grants stale
  authority; posting retry safety (zero double-posts).
- **Latency:** delegation approval→first-posting wait dominated by the
  customer's approval action, not by the platform (short polling intervals);
  internal-account resolution cached per session.
- **Security:** zero credential sharing; every customer operation attributable
  to (teller, customer, operation) and audited end to end.
- **Compliance:** manual decisions and DLQ replay are deliberate staff
  actions with audit trails.
- **UX quality:** counter flows complete within a few clicks; receipts
  printable immediately after posting.

## 8. Dependencies & Reliance on Other Services

| Dependency | Why |
|---|---|
| Sentin8:Auth | Teller sign-in, CIBA approval journeys |
| Sentin8:BFF | Session, delegation gateway (`/delegate/*`), delegated-token issuance, WebSocket |
| Bank8:Ledger | Customers, accounts, products, postings, batches, statements, DLQ, internal accounts |
| Bank8:Payments | Approval tasks, manual decisions |
| Sentin8:App | Instance provisioning, runtime context, listing |
| Sentin8:TLS | Hostname → instance resolution, TLS termination |

## 9. Acceptance Criteria

1. A teller can find a customer and start a delegation; the customer approves
   on their own device; the teller then performs the operation under the
   delegated authority.
2. A delegation expiry or customer denial always blocks the operation - never
   proceeds on stale authority.
3. Cash/cheque deposits and withdrawals post against the correct internal
   counterparty accounts without the teller typing account numbers.
4. A teller-initiated operation retried for any reason cannot double-post.
5. Staff can review batches and DLQ entries; DLQ republish is an explicit
   staff action.
6. Manual decisions and approval tasks render with the correct state and act
   through the payments service only.
7. The shift summary reflects the teller's current-shift activity.
8. E2E: the full teller journey (sign-in → search → CIBA approval from the
   customer's session → cash deposit → receipt) runs through the browser,
   like a real staff member and a real customer.

## 10. Open Business Questions

- Should cheque settlement (cleared/bounced) conclude through the ledger
  cheque pipeline automatically once received (removing the current
  client-tracked pending state)?
- Should the end-of-day shift/cash reconciliation become a server-side
  session record rather than a device-local summary?

---

**Design attribution:** bank8:eteller and its underlying concepts were designed by Hamid Jahanzad <Hamid@Jahanzad.com>.
