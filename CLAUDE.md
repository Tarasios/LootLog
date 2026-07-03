\# DuoBudget



Two-person local-first shared budgeting app. Flutter (Android + desktop) + Go sync server.



\## Non-negotiable invariants

\- Money is integer cents everywhere. Never float/double for money. `Money` value type only.

\- All state changes are immutable events appended to the local `events` table. Never UPDATE/DELETE domain rows. Corrections = compensating events (e.g., PurchaseVoided).

\- All derived state comes from `lib/domain/reducer.dart` — a pure function `List<Event> → HouseholdState`. UI and sync code never compute balances themselves.

\- Month rollover, purchase splitting, and goal estimates are computed in the reducer at read time. No scheduled jobs, no mutation on month boundaries.

\- Odd cents on shared splits go to the purchaser.

\- Months are calendar months in the household timezone (America/Vancouver), keyed by purchase `occurredAt`, not `createdAt`.

\- Event IDs are UUIDv7. Events are globally ordered by (occurredAt for domain semantics, server seq for sync).



\## Stack

Flutter stable + Riverpod (codegen) + drift + go\_router + fl\_chart. Server: Go 1.22, stdlib net/http + modernc.org/sqlite (cgo-free), single binary, Dockerfile provided. No paid services or SaaS SDKs of any kind.



\## Structure

\- `app/` Flutter project. `lib/domain/` (pure Dart, zero Flutter imports), `lib/data/` (drift, sync client), `lib/features/<name>/` (UI per feature).

\- `server/` Go sync server.

\- `docs/` ADRs and protocol spec.



\## Workflow rules

\- TDD for `lib/domain/`: write/extend reducer tests before implementation. `flutter test` must pass before any commit.

\- Run `dart analyze` and `gofmt`/`go vet`; fix all warnings.

\- Conventional commits, one commit per completed task.

\- Do not add dependencies beyond those listed without stating why in the commit body.

\- Do not build features not in the current phase prompt.

