# Changelog

## v0.5.1 — Swimmer profiles per family (current)

Coach circled back: she does want per-kid profiles after all so she can see age + season group at a glance. Adds a small `swimmers` table layered on top of the whitelist; one parent email can have multiple swimmers.

### Added
- **`swimmers` table** — keyed by parent_email FK to `parents.email` (cascade delete: removing a parent from whitelist also drops their swimmers). Stores `swimmer_name`, `birth_year`, `birth_month`, `notes`. Read-public, write-coach RLS.
- **学员 chips in whitelist row** — each parent row now shows their swimmers as inline pills with current age + USA-Swimming-style age group (8&U / 9-10 / 11-12 / 13-14 / 15+).
- **学员管理 modal** — click "管理学员 (n)" on any parent row to add/edit/delete swimmers in a focused dialog. Empty birth year/month is allowed (just shows "未填生日").
- **Parent-side hint** — when a whitelisted parent enters their email, the page now shows "本邮箱名下学员: 张小明 (8岁) · 张小红 (5岁)" so they fill in the right child name on each booking.

### Changed
- Bookings still store `child_name` as free text (no swimmer_id FK). Swimmer profiles are coach-managed reference data — useful for visibility but not enforced at booking time. Existing bookings keep working unchanged.
- Backup JSON now includes `swimmers` array; restore upserts them.

### Migration
- Run `migrations/2026-04-29-swimmers.sql` against the live DB. Idempotent.
- Schema bumped v5 → v5.1 (additive — no existing rows touched).

## v0.5.0 — Whitelist + 7-day cancel deadline

Driven by coach feedback round 1 (2026-04-28). Phase 1 of the v2 spec — schema and UI groundwork only; email-based confirm flow comes in a later phase.

### Added
- **Parent whitelist** (`parents` table) — only emails on the whitelist can create bookings or recurring requests. Enforced at both UI (live status under email field, hard-block on submit) and RLS layers.
- **Coach view "白名单" tab** — coach (and admin) can add, edit notes for, mark as Regular, or remove parents from the whitelist. Removing a parent auto-cancels their future single bookings, ends their active recurrings, and rejects their pending requests, with a confirmation dialog showing the impact. Multi-child families share one parent email; child names go on each booking as they always have.
- **Releases status fields** (`status`, `confirm_token`, `confirmed_at`) — placeholder columns for the upcoming T-10 / 24h confirm flow. No behavior wired up yet.
- **Realtime subscription** on `parents` so admin actions propagate instantly to parent UIs.

### Changed
- **Self-cancel deadline** from 12 hours to 7 days before class. Parents inside the 7-day window see "距上课<7天 / 请联系教练" instead of a cancel button. New constant `CANCEL_DEADLINE_HOURS` makes this easy to tweak.
- Stat card on admin overview now shows total whitelist count and Regular subset.

### Migration
- Run `migrations/2026-04-28-whitelist-and-release-status.sql` against the live DB. Idempotent — safe to re-run.
- Schema bumped v4 → v5. Existing bookings/recurrings are not retroactively whitelisted; admin needs to populate the whitelist before parents can place new bookings.

### Known gaps (intentional, deferred to next phase)
- Email infrastructure not yet built (no Resend integration, no Edge Functions). The `confirm_token`/`confirmed_at` columns sit unused until then.
- Swimmer entities (birth year/month, multi-child per parent) deferred — coach asked, but Michelle chose to ship simpler.

## v0.4.0 — Beta

### Added
- **Admin role** for Zoe Stella with hidden `⚡ Admin` portal (7 tabs: overview, bookings, recurring, releases, users, raw JSON, danger zone)
- **`app_admins` table** + `is_admin()` SQL helper for permanent developer access independent of who the coach is
- **Realtime subscriptions** on releases / bookings / recurring_requests / recurring_approved — coach publishes a slot, parent's open page updates instantly without refresh
- **Backup/restore** — admin can download full data as JSON, re-import on demand
- **Force operations** for admin: cancel/restore any booking, terminate any recurring, physically delete any row, wipe-all with `WIPE` typed confirmation
- **System overview** in admin: parent → child mappings, total counts, current state snapshot

### Changed
- Schema bumped from v3 → v4 (added `app_admins` and `is_admin()` function)
- RLS policies updated: admins implicitly have full access via `auth.role() = 'authenticated'`; the admin portal is a UI gate, not a separate auth tier

## v0.3.0 — Cloud version

### Added
- **Supabase backend** replacing localStorage — true multi-device sync
- **Coach login** — email + password via Supabase Auth, only authenticated users can publish/approve/check-in
- **Hidden coach portal** — parents never see the admin button or the coach surface
- **Approval workflow for recurring** — parent requests, coach approves; only approved recurrings auto-book on matching releases
- **5-table schema** with RLS policies separating anonymous / authenticated tiers

### Changed
- Timezone locked to `America/New_York` (was using browser-local in earlier iterations)
- Recurring auto-book now requires explicit coach approval (was implicit before)

## v0.2.0 — 30-minute slots + recurring approval

### Added
- 30-minute slot granularity (was hourly): 7:00 / 7:30 / 8:00 / ... / 20:30
- Coach-controlled recurring permissions (parents request, coach approves)

### Fixed
- Date/timezone bug where `new Date('2026-04-27')` was parsed as UTC then shifted by browser tz, causing schedule misalignment between coach and parent views

## v0.1.0 — Local prototype

- Single-file HTML with localStorage persistence
- Hourly slot grid (7:00 / 8:00 / ...)
- Family-name fields (child + parent), coach calendar with attendance
- 12-hour parent-cancel window
- CSV export
- Coach week-publish flow
