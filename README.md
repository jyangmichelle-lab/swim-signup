# Lesson Scheduler

A web-based lesson scheduling app for private swim coaches and the parents of their students. Single-coach, multi-family, with a public booking page and a coach-only admin portal.

> **Status:** Beta — actively under development by Zoe Stella.

## What it does

- **Coach** publishes available 30-minute time slots each week (calendar UI)
- **Parents** sign up children for slots without creating an account (identified by parent email)
- **Recurring requests** — parents can request a fixed weekly slot; the coach approves; future matching slots are auto-booked when published
- **12-hour cancel window** — parents self-cancel up to 12 h before the lesson; closer than that, contact the coach
- **Attendance tracking** — coach marks present/absent per lesson; recurring lessons get per-date attendance
- **CSV export** — weekly schedule export for record-keeping
- **Realtime sync** — coach publishes a slot, parent's open page updates instantly (no refresh)
- **Admin backdoor** — Zoe Stella has a hidden `⚡ Admin` portal: raw data view, force operations, full backup/restore, danger-zone wipes

## Tech stack

- **Frontend:** Single `index.html` file (vanilla JS, no build step). Tailwind-free; custom CSS with Fraunces + Manrope fonts.
- **Backend:** [Supabase](https://supabase.com) free tier
  - Postgres database (5 tables)
  - Row-Level Security policies (parent / coach / admin tiers)
  - Auth (email + password, coaches and admins only)
  - Realtime (postgres_changes subscriptions on all 4 business tables)
- **Hosting:** GitHub Pages (free, static)
- **Timezone:** Locked to `America/New_York` — DST handled automatically

## Cost

**$0/month** at expected scale (1 coach, ~50 families). Supabase free tier limits: 500 MB DB, 5 GB egress/mo, 50,000 MAU. We'll use <1% of each.

Free Supabase projects pause after 7 days of inactivity. Any traffic prevents this; data is preserved across pauses.

## File layout

```
lesson-scheduler/
├── index.html      # The whole app — single file, no build
├── schema.sql      # Database schema + RLS policies + Realtime setup
├── DEPLOY.md       # Step-by-step deployment guide (Supabase + GitHub Pages)
├── README.md       # You are here
└── CHANGELOG.md    # Version history
```

## Quick start

If this is your first time setting up: read [DEPLOY.md](./DEPLOY.md). It walks through Supabase project creation, schema execution, admin account setup, and GitHub Pages deployment. Plan ~30–45 minutes.

If you already have it deployed and just want to develop:

1. Clone the repo locally
2. Open `index.html` in a browser — works directly from `file://`
3. Make sure `SUPABASE_URL` and `SUPABASE_ANON_KEY` near the top of `index.html` point to your project
4. Edit, save, refresh

## Architecture notes

### Data model

| Table | Purpose | Who can write |
|---|---|---|
| `app_admins` | Super-admin user list (Zoe Stella) | admins |
| `releases` | Time slots the coach has opened for booking | coaches + admins |
| `bookings` | One-off lesson signups | anyone (insert), anyone (cancel via update), coach (delete) |
| `recurring_requests` | Parent applications for a weekly slot | anyone (insert), coach (status update) |
| `recurring_approved` | Approved recurring lessons (auto-book on matching releases) | coach (insert), anyone (cancel single date), coach (terminate) |

Per-recurring-lesson attendance lives in `recurring_approved.attendance` as `jsonb` keyed by ISO date.

### Auth & roles

Three privilege levels:

1. **Anonymous (parents)** — read everything (slot availability matters), insert bookings + recurring_requests, update bookings.cancelled and recurring_approved.cancelled_dates. Identified by self-reported email.
2. **Authenticated (coach)** — everything anonymous can do + write to releases, update recurring_requests.status, insert/delete recurring_approved.
3. **Admin (Zoe)** — `app_admins` membership grants UI access to the `⚡ Admin` portal. Operationally still uses authenticated role; the admin portal just gives a different UI surface (raw tables, force ops, danger zone). Backed by `is_admin()` SQL helper for any future admin-only RLS.

### Realtime

The schema enables `supabase_realtime` publication on all 4 business tables. Frontend subscribes via `sb.channel().on('postgres_changes', ...)` to all of them, with a 300 ms debounce that re-fetches and re-renders on any change. This is why parent and coach screens stay in sync without polling.

### Timezone

All date/time math is anchored to `America/New_York` via `Intl.DateTimeFormat` with `timeZone: 'America/New_York'`. Never uses the browser's local timezone. The `etDateMinuteToInstant()` helper does an iterative correction (max 3 passes) to handle DST transitions cleanly. Date strings stored in DB are calendar dates in ET (`YYYY-MM-DD`), minutes-since-midnight as `int`.

## Working with this codebase

### Local development

No build step. No package.json. No node_modules. Just open `index.html`.

The Supabase JS SDK loads from a CDN (`@supabase/supabase-js@2`).

### Modifying the schema

1. Write a migration as new SQL (don't edit `schema.sql` for an already-deployed schema — that file is for fresh deploys)
2. Run the migration in Supabase Dashboard → SQL Editor
3. Update `schema.sql` to reflect the new fresh-deploy state
4. Add a CHANGELOG entry

### Deploying changes

Push the new `index.html` to GitHub. Pages auto-rebuilds in 1–2 minutes. No CI needed.

### Admin backdoor

The `⚡ Admin` button only appears if `app_admins` contains your authenticated user's UUID. Lose admin? Re-add yourself via SQL Editor (you own the Supabase project, so you always can).

## Roadmap (post-beta)

In rough priority order:

- [ ] **Email notifications** via Resend + Supabase Edge Functions (recurring approve/reject, lesson reminders 24h before)
- [ ] **Parent email verification** — magic-link sign-in to prevent email spoofing
- [ ] **Coach lesson notes** — per-attendance freeform notes the coach can review later
- [ ] **Multi-coach support** — `coaches` table, `coach_clients` mapping, RLS scoped per coach
- [ ] **Lesson packages / credits** — pre-paid bundles with auto-decrement
- [ ] **Push notifications** for upcoming lessons (web push, no email needed)
- [ ] **Mobile-optimized layouts** — current responsive design works but can be tighter on phones
- [ ] **Calendar export** — `.ics` feed each parent can subscribe to in their phone calendar

## License

Private. Not yet open-sourced.
