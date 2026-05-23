# Covey launch checklist

This checklist captures the remaining non-code steps for the public Covey validation push.

## 1. Review and merge the landing-page PR

Branch: `feat/public-landing-page`

What it includes:

- Public landing page at `/`
- Authenticated product moved under `/app/*`
- Waitlist form on the landing page
- Supabase migration for `waitlist_signups`
- SEO/social metadata for `covey.zachmartens.com`

## 2. Apply the waitlist migration in Supabase

Run the migration in Supabase before announcing the page:

```sql
supabase/migrations/20260523000001_waitlist.sql
```

Expected result:

- Creates `waitlist_signups`
- Allows anonymous inserts from the public landing page
- Does not allow anonymous/public reads
- Treats duplicate emails as already joined in the frontend

## 3. Confirm GitHub Pages environment secrets

The deploy workflow expects these repository secrets:

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`

Without them, the landing page still renders, but the waitlist form falls back to the manual email message.

## 4. Fix GitHub Pages HTTPS

Current diagnosis from Hermes on 2026-05-23:

- `covey.zachmartens.com` resolves correctly to GitHub Pages through `zmarten.github.io`.
- GitHub Pages repo config has `cname: covey.zachmartens.com`.
- GitHub Pages currently reports `https_enforced: false`.
- The served certificate is still GitHub's wildcard cert (`*.github.io`) and does **not** include `covey.zachmartens.com`, causing the browser SSL hostname mismatch.

Recommended action in GitHub:

1. Open repo settings for `zmarten/covey-ledger`.
2. Go to **Pages**.
3. Confirm custom domain is `covey.zachmartens.com`.
4. Wait for GitHub's DNS/certificate check to finish if it is pending.
5. Enable **Enforce HTTPS** once GitHub shows the certificate is available.

If GitHub still will not issue the cert:

- Remove and re-add the custom domain in Pages settings.
- Confirm Cloudflare DNS is **DNS only**, not proxied, for the GitHub Pages record while the certificate is issuing.
- Re-run the deploy workflow after the custom domain is saved.

## 5. Smoke-test production after merge/deploy

Check:

- `https://covey.zachmartens.com/` loads without certificate warnings.
- `/` shows the public landing page.
- `/login` shows auth.
- `/app` redirects unauthenticated visitors to `/login`.
- Waitlist insert creates a row in `waitlist_signups`.
- A duplicate email shows success instead of an error.

## 6. First validation push

Share as an early-access/free-tool project, not a polished SaaS pitch:

- Garmin hunting/watch groups
- onX/Garmin waypoint discussions
- upland hunting communities
- Personal network of hunters/guides

Track:

- visits
- waitlist signups
- replies about the strongest pain point
- whether WaypointBridge or the field-to-freezer ledger gets more interest
