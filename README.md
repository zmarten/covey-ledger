# Covey Ledger

Covey Ledger is an early-stage hunting workflow for upland hunters: capture what happened in the field, bring it into a freezer ledger, and keep a practical view of daily and possession-limit pressure.

## Current launch surface

- `/` — public validation landing page and waitlist
- `/login` — existing app authentication
- `/app/*` — authenticated Covey application

## Local development

```bash
npm install
npm run dev
```

## Production build

```bash
npm run build
```

## Waitlist setup

The public landing page writes to Supabase when these Vite environment variables are available at build/deploy time:

```bash
VITE_SUPABASE_URL=...
VITE_SUPABASE_ANON_KEY=...
```

Apply the migration before launch:

```text
supabase/migrations/20260523000001_waitlist.sql
```

The migration creates `waitlist_signups`, allows anonymous inserts, and intentionally does not allow public reads.

The waitlist client emits optional `plausible`/`gtag` events if either analytics library is already loaded by the page. No analytics provider is configured by this branch, and analytics failures are ignored so they cannot block signup.

If the Supabase env vars are missing, the landing page still renders and asks visitors to email `zachdmartens@gmail.com` for early access.

## Launch docs

- `docs/covey-launch-checklist.md` — approval/deploy/smoke-test checklist
- `docs/covey-launch-copy.md` — reusable copy for outreach and posts
- `docs/covey-validation-plan.md` — first-week validation plan and success metrics
