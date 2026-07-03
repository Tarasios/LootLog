1.1 Stack: Flutter (Dart)



One codebase → Android + Windows/macOS/Linux desktop, with genuinely polished UI (this is the showcase requirement). Alternatives rejected: Kotlin Multiplatform (desktop story less mature), Tauri + separate Android app (two codebases), Electron (no Android).





State management: Riverpod (v2, code-gen)

Local DB: SQLite via drift (typed, reactive queries — the UI updates live when sync lands)

Navigation: go\_router

Charts: fl\_chart (free, pretty)





1.2 Sync: event-sourced ledger + tiny self-hosted server



This is the load-bearing decision. Do not sync mutable rows (conflict hell). Instead:





Every client writes immutable events to its local SQLite: PurchaseAdded, PurchaseVoided, BudgetSliceSet, IncomeSet, FixedExpenseSet, GoalSet, AccountBalanceRecorded, SettingChanged.

Events are append-only, each with {eventId (UUIDv7), deviceId, userId, createdAt (UTC), type, payload (JSON)}.

All visible state (budget remaining, splits, rollovers, goal progress, net worth) is a pure reduction of the event log. Corrections are new events (PurchaseVoided + re-add), never edits.

Sync server is a \~300-line Go service (single static binary, SQLite file, Docker image): POST /events (append batch), GET /events?after=<seq> (pull), per-device cursor. Last-writer concerns disappear because nothing is overwritten.

Clients push local unsynced events and pull on app open, on foreground, and every 60s while active. Fully usable offline; converges when online.





Why this wins for exactly 2 users: no CRDT library, no operational transforms, deterministic replays, trivially testable reducer, and the month-end rollover needs no scheduled job (see 1.4).



1.3 Hosting \& networking: free, no port forwarding





Server runs in Docker on any always-on-ish machine (old laptop, Pi, or Oracle Cloud Always Free tier if you want it off-site).

Connectivity via Tailscale (free personal plan, 2 users fine): both phones + desktops + server join one tailnet. Encrypted, no exposed ports, no domain, no TLS certs to manage. Clients hit http://budget-server:8080 over the tailnet.

Auth stays simple but real: a shared household secret provisions each device once; server issues a per-device bearer token stored in platform secure storage.





1.4 Money \& time semantics (non-negotiable correctness rules)





All money is integer cents. No doubles anywhere in domain code.

Months are calendar months in a configured household timezone (America/Vancouver). An event belongs to the month of its occurredAt (user-editable purchase date, distinct from createdAt).

Rollover is computed, not executed. "Leftover entertainment goes to personal global budget" is derived at read time: for each closed month, carryover(user) = Σ max(0, slice\_limit − slice\_spent) over slices flagged rolloverToGlobal. Global budget for month M = base + Σ carryovers of all closed months < M. No cron, no "who runs the job on the 1st" race between two clients, retroactive event sync (a purchase entered late for last month) automatically re-derives everything correctly.

Group purchase: stored once by the purchaser with isShared=true; the reducer attributes cost/2 (rounded, odd cent to purchaser) against each user's matching slice. Splitting is a view-time computation, so a purchase can be toggled shared/personal by a correcting event.

Fixed shared expenses (rent, utilities): FixedExpenseSet events define amount + split; the reducer deducts each user's share off the top of monthly available budget before slices.





1.5 Domain model (reducer output shapes)



Household { timezone, users\[2], settings { showNetWorth: bool } }

UserMonth {

&#x20; incomeCents, fixedShareCents,

&#x20; slices: \[ { name, limitCents, spentCents, rolloverToGlobal } ],

&#x20; globalBudget: { baseCents, carryoverCents, spentCents, remainingCents }

}

Purchase { id, userId, occurredAt, amountCents, sliceId, isShared, note, voided }

Goal { targetCents, startedAt } → GoalProgress {

&#x20; savedCents,                       // Σ monthly net (income − all spend − fixed share)

&#x20; pctComplete,

&#x20; estMonthsRemaining                // trailing 3-month avg net savings; null if avg ≤ 0

}

NetWorth (feature-flagged) { accounts: \[ {name, kind: cash|investment|debt, latestBalanceCents} ], totalCents }



Net worth is manual entry only (AccountBalanceRecorded) — bank aggregation APIs (Plaid etc.) are paid, so they're out by requirement.



1.6 UX requirements to enforce throughout





Expense entry ≤ 3 interactions: big FAB → amount keypad (auto-focused) → tap a slice chip → done. Shared toggle and note are optional inline. Under 5 seconds in a grocery line.

Status screen is the showcase: per-slice progress rings, month burn-down, partner activity feed, goal progress card with "≈ N months to go".

Desktop is not a stretched phone: navigation rail, two-pane layout (slices | activity), keyboard shortcut N for new expense.

Optimistic UI: events apply locally instantly; sync indicator is subtle (small dot, never a spinner blocking input).





1.7 Component diagram



\[Android app]──┐                       ┌──\[Desktop app]

&#x20; drift/SQLite │   Tailscale tailnet   │ drift/SQLite

&#x20; (event log + ├──►\[Go sync server]◄───┤ (event log +

&#x20;  snapshot)   │     SQLite, Docker    │  snapshot)

&#x20;              └── push/pull events ───┘

&#x20;       UI = reduce(events)  ← identical pure Dart on both



1.8 What to revisit if it grows





2 users → configurable split ratios (payload already carries them); event log gets big (years) → monthly snapshot checkpoints in the reducer (schema supports it from day one via snapshots table, implement lazily); server loss → any client can re-seed it (clients are full replicas).

