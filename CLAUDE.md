# Lesson Scheduler — Notes for Claude

This file is read by Claude Code when working on this project. It captures conventions and context that aren't obvious from the code alone.

## Project context

A swim-coach lesson scheduling web app being built and maintained by **Zoe Stella** (developer, not the coach). Currently in beta. The intended end-user is a single private swim coach in RTP, North Carolina, plus the parents of their student-athletes.

## Stack constraints — read before suggesting changes

- **No build step. No bundler. No npm.** This is a deliberate choice. The app is a single `index.html` that loads Supabase JS from a CDN. Any change must keep this property — do not propose React/Vite/etc. unless the user explicitly asks to switch.
- **Single-file architecture.** `index.html` contains all HTML, CSS, and JS. Keep it that way unless the file becomes unmaintainable (currently ~1900 lines, fine).
- **Vanilla JS only.** No jQuery, no Lodash, no framework. Direct DOM manipulation. Use modern syntax (async/await, optional chaining, template literals).
- **Supabase free tier only** (for now). Don't suggest features that require paid Supabase tiers (read replicas, point-in-time recovery, etc.) without flagging the cost trade-off.

## Timezone — critical

All date/time logic is anchored to `America/New_York`, NEVER to the browser's local timezone. The user has been bitten by tz bugs already. Key rules:

- Don't use `new Date('YYYY-MM-DD')` to parse a date — it's parsed as UTC and shifts. Use the existing `parseDateStr()` helper which returns `{y, m, d}` in ET.
- Don't use `date.getHours()` etc. directly — they return browser-local values. Use `toET(date)` to get ET-anchored components.
- For "what's the UTC instant of `Y-M-D HH:MM` in ET", use `etDateMinuteToInstant()` — it does iterative DST correction.
- Date strings stored in DB are calendar dates in ET (`YYYY-MM-DD`), not timestamps.
- Time-of-day is stored as `int` minutes-since-midnight (e.g. 10:30 = 630).

Test any change touching dates by trying it during DST transition weeks (around 2nd Sunday of March, 1st Sunday of November in the US).

## Roles & permissions model

Three tiers, all enforced at two layers (UI + Postgres RLS):

1. **Anonymous (parents)** — no account, identified by self-reported email. Can read all tables, insert into `bookings` and `recurring_requests`, update `bookings.cancelled` and `recurring_approved.cancelled_dates`.
2. **Authenticated (coach)** — Supabase Auth user. Everything anonymous can do, plus full write access to `releases`, `recurring_requests` status updates, `recurring_approved` insert/delete.
3. **Admin (Zoe Stella)** — authenticated user whose UUID is in `app_admins`. UI-level distinction: shows the `⚡ Admin` button and grants access to the admin portal. Operationally uses the same authenticated role for DB ops; the admin gate is in the UI. The `is_admin()` SQL function exists for any future admin-only RLS policies.

When adding features, ask which tier(s) need access, and update both the UI conditionals AND the RLS policy in `schema.sql`.

## Code style observations

- Chinese is used for all user-facing strings (the user is bilingual; coach's clients are Chinese-speaking families). Comments and developer-facing strings can be Chinese or English; the user accepts both.
- Variable/function names are English.
- CSS uses CSS custom properties (`--ink`, `--water-deep`, etc.) — keep using them, don't inline colors.
- Toast messages: `toast(msg)` for info, `toast(msg, true)` for errors (turns red).
- Realtime updates auto-trigger `refreshAllData()` + `renderAll()` via `onRealtimeChange()` with 300ms debounce. Don't manually call those after a `sb.from(...)` write — Realtime will handle it.

## Things the user has explicitly NOT wanted

- React, Vue, any framework
- A separate backend server (Edge Functions are OK because they're Supabase-hosted)
- Paid hosting
- Forcing parents to create accounts (they identify by email; this is a known weak spot but accepted for the beta)

## Things the user has explicitly wanted

- Real-time sync (parent and coach see updates without refresh) ✓ done
- Permanent developer/admin access for Zoe regardless of who the coach is ✓ done
- Lock to ET timezone ✓ done
- $0/month operating cost ✓ done
- Single-file deployment for easy GitHub Pages hosting ✓ done

## Pending / next features the user mentioned

- Email notifications (recurring approval, 24h-before reminder) — would use Resend's free tier + Supabase Edge Functions; user has not confirmed whether they have a domain for Resend
- Parent email verification (magic link login) to fix the email-spoofing weakness

## Local dev workflow

```bash
# Just open index.html in a browser
open index.html
# or
python3 -m http.server 8000  # then visit localhost:8000
```

There's no test suite yet. When making changes that touch date/timezone logic, manually verify in browser console:
```javascript
toET(new Date()) // should show current ET time
parseDateStr('2026-04-27') // should return {y: 2026, m: 4, d: 27}
hoursUntilClass('2026-04-27', 600) // should be hours-from-now
```

## Deployment

`index.html` is uploaded to GitHub (repo name: `lesson-scheduler` or whatever the user chose). GitHub Pages serves it. The `SUPABASE_URL` and `SUPABASE_ANON_KEY` constants near the top of the file must be filled in before the app works. The `anon` key is meant to be public — security comes from RLS policies, not key secrecy.

To deploy a change: commit + push, GitHub Pages rebuilds in 1–2 minutes.

## Schema changes

`schema.sql` represents the schema for a fresh deploy. If you need to change the live schema:

1. Write a migration (`-- 2026-XX-XX add_column_x.sql` or similar)
2. Have the user run it in Supabase SQL Editor
3. Update `schema.sql` to match new state
4. Add a CHANGELOG entry

Don't edit `schema.sql` and assume the live DB is updated — the live DB only changes when SQL is run against it.
