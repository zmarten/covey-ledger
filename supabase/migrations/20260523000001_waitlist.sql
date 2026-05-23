-- Covey Ledger — Public waitlist capture
-- Allows anonymous landing-page visitors to request early access without creating an app account.

CREATE TABLE IF NOT EXISTS waitlist_signups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL,
  states_hunted text,
  tools_used text,
  biggest_pain text,
  source text NOT NULL DEFAULT 'landing',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT waitlist_signups_email_unique UNIQUE (email),
  CONSTRAINT waitlist_signups_email_not_blank CHECK (length(trim(email)) > 3),
  CONSTRAINT waitlist_signups_email_shape CHECK (email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$')
);

ALTER TABLE waitlist_signups ENABLE ROW LEVEL SECURITY;

-- Landing-page visitors can submit; no public select policy is defined.
CREATE POLICY "waitlist_signups_insert_anon" ON waitlist_signups
  FOR INSERT TO anon
  WITH CHECK (true);

CREATE POLICY "waitlist_signups_insert_authenticated" ON waitlist_signups
  FOR INSERT TO authenticated
  WITH CHECK (true);
