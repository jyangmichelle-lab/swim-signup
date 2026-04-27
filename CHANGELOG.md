# Changelog

## v0.4.0 — Beta (current)

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
