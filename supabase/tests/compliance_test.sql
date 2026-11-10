-- Compliance engine tests. Run by run.sh against a throwaway local database.
-- Every case acts as a signed-in user through RLS, the way the app does.
-- Each case uses its own state so cases cannot affect one another.
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on

CREATE SCHEMA t;
CREATE TABLE t.results (n serial, label text, expected text, got text, detail text);
GRANT USAGE ON SCHEMA t TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA t TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA t TO authenticated;

INSERT INTO auth.users (id, email) VALUES
  ('00000000-0000-0000-0000-00000000000a', 'a@example.test'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.test'),
  ('00000000-0000-0000-0000-00000000000c', 'c@example.test');

-- Pheasant in every state: daily limit 3, possession limit 9.
INSERT INTO regulations (state_id, species_id, daily_limit, possession_limit)
SELECT s.id, sp.id, 3, 9 FROM states s, species sp WHERE sp.name = 'Pheasant';

CREATE FUNCTION t.st(abbr text) RETURNS uuid LANGUAGE sql AS
  $$ SELECT id FROM public.states WHERE abbreviation = abbr $$;
CREATE FUNCTION t.ph() RETURNS uuid LANGUAGE sql AS
  $$ SELECT id FROM public.species WHERE name = 'Pheasant' $$;

-- Log a harvest as the current user. Returns the entry id.
CREATE FUNCTION t.harvest(abbr text, qty int, d date) RETURNS uuid LANGUAGE sql AS $$
  INSERT INTO public.harvest_entries (user_id, state_id, species_id, quantity, date)
  VALUES (auth.uid(), t.st(abbr), t.ph(), qty, d) RETURNING id $$;
CREATE FUNCTION t.consume(abbr text, qty int) RETURNS uuid LANGUAGE sql AS $$
  INSERT INTO public.consumptions (user_id, state_id, species_id, quantity)
  VALUES (auth.uid(), t.st(abbr), t.ph(), qty) RETURNING id $$;
CREATE FUNCTION t.distribute(entry uuid, qty int) RETURNS uuid LANGUAGE sql AS $$
  INSERT INTO public.distributions (harvest_entry_id, quantity_distributed)
  VALUES (entry, qty) RETURNING id $$;
-- The entry the current user logged in a state on a date.
CREATE FUNCTION t.entry(abbr text, d date) RETURNS uuid LANGUAGE sql AS $$
  SELECT id FROM public.harvest_entries
  WHERE user_id = auth.uid() AND state_id = t.st(abbr) AND date = d LIMIT 1 $$;

-- Run one statement as a user and record whether the database allowed it.
-- A statement that touches no rows counts as blocked (RLS filtered it out).
CREATE FUNCTION t.try(label text, usr text, expected text, q text) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE got text; detail text := ''; n bigint;
BEGIN
  PERFORM set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000' || usr, false);
  BEGIN
    EXECUTE q;
    GET DIAGNOSTICS n = ROW_COUNT;
    got := CASE WHEN n = 0 THEN 'blocked' ELSE 'allowed' END;
    IF n = 0 THEN detail := 'no rows affected'; END IF;
  EXCEPTION WHEN OTHERS THEN
    got := 'blocked'; detail := SQLERRM;
  END;
  IF expected IS NOT NULL THEN
    INSERT INTO t.results (label, expected, got, detail) VALUES (label, expected, got, detail);
  ELSIF got = 'blocked' THEN
    RAISE EXCEPTION 'setup step failed (%): %', label, detail;
  END IF;
END $$;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA t TO authenticated;

SET ROLE authenticated;

-- ---------- Things that must keep working ----------
SELECT t.try('ok: harvest at the daily limit', 'a', 'allowed', $$SELECT t.harvest('KS', 3, '2026-11-01')$$);
SELECT t.try('ok: distribute part of an entry', 'a', 'allowed', $$SELECT t.distribute(t.entry('KS','2026-11-01'), 2)$$);
SELECT t.try('ok: consume a bird you hold', 'a', 'allowed', $$SELECT t.consume('KS', 1)$$);
SELECT t.try('ok: another user has their own limits', 'b', 'allowed', $$SELECT t.harvest('KS', 3, '2026-11-01')$$);
SELECT t.try('ok: delete an untouched entry', 'b', 'allowed', $$DELETE FROM public.harvest_entries WHERE id = t.entry('KS','2026-11-01')$$);
SELECT t.try('ok: no regulation on file still logs', 'a', 'allowed',
  $$INSERT INTO public.harvest_entries (user_id, state_id, species_id, quantity, date)
    SELECT auth.uid(), t.st('KS'), id, 20, '2026-11-01' FROM public.species WHERE name = 'Dove'$$);

-- ---------- Daily limit ----------
SELECT t.try('daily: direct insert over the limit', 'a', 'blocked', $$SELECT t.harvest('SD', 4, '2026-11-01')$$);
SELECT t.try(NULL, 'a', NULL, $$SELECT t.harvest('SD', 2, '2026-11-02')$$);
SELECT t.try('daily: second entry pushes the day over', 'a', 'blocked', $$SELECT t.harvest('SD', 2, '2026-11-02')$$);
SELECT t.try('daily: edit an entry up past the limit', 'a', 'blocked',
  $$UPDATE public.harvest_entries SET quantity = 50 WHERE id = t.entry('SD','2026-11-02')$$);
SELECT t.try(NULL, 'a', NULL, $$SELECT t.harvest('SD', 3, '2026-11-03')$$);
SELECT t.try('daily: move an entry onto a full day', 'a', 'blocked',
  $$UPDATE public.harvest_entries SET date = '2026-11-03' WHERE id = t.entry('SD','2026-11-02')$$);

-- ---------- Possession limit ----------
SELECT t.try(NULL, 'a', NULL, $$SELECT t.harvest('ND', 3, '2026-11-01')$$);
SELECT t.try(NULL, 'a', NULL, $$SELECT t.harvest('ND', 3, '2026-11-02')$$);
SELECT t.try(NULL, 'a', NULL, $$SELECT t.harvest('ND', 3, '2026-11-03')$$);
SELECT t.try('possession: tenth bird on a new day', 'a', 'blocked', $$SELECT t.harvest('ND', 1, '2026-11-04')$$);

SELECT t.try('possession: consume birds you never had', 'a', 'blocked', $$SELECT t.consume('NE', 100)$$);

SELECT t.try(NULL, 'a', NULL, $$SELECT t.harvest('IA', 3, '2026-11-01')$$);
SELECT t.try('possession: distribute more than the entry holds', 'a', 'blocked',
  $$SELECT t.distribute(t.entry('IA','2026-11-01'), 30)$$);
SELECT t.try(NULL, 'a', NULL, $$SELECT t.distribute(t.entry('IA','2026-11-01'), 2)$$);
SELECT t.try('possession: second distribution overdraws the entry', 'a', 'blocked',
  $$SELECT t.distribute(t.entry('IA','2026-11-01'), 2)$$);
SELECT t.try('possession: edit an entry below what was distributed', 'a', 'blocked',
  $$UPDATE public.harvest_entries SET quantity = 1 WHERE id = t.entry('IA','2026-11-01')$$);

-- Give birds away, refill to the limit, then take the giveaway back.
SELECT t.try(NULL, 'a', NULL, $$SELECT t.harvest('MN', 3, '2026-11-01')$$);
SELECT t.try(NULL, 'a', NULL, $$SELECT t.harvest('MN', 3, '2026-11-02')$$);
SELECT t.try(NULL, 'a', NULL, $$SELECT t.harvest('MN', 3, '2026-11-03')$$);
SELECT t.try(NULL, 'a', NULL, $$SELECT t.distribute(t.entry('MN','2026-11-01'), 3)$$);
SELECT t.try(NULL, 'a', NULL, $$SELECT t.harvest('MN', 3, '2026-11-04')$$);
SELECT t.try('possession: delete a distribution while at the limit', 'a', 'blocked',
  $$DELETE FROM public.distributions WHERE harvest_entry_id = t.entry('MN','2026-11-01')$$);

-- Same trick with a consumption record.
SELECT t.try(NULL, 'a', NULL, $$SELECT t.harvest('MT', 3, '2026-11-01')$$);
SELECT t.try(NULL, 'a', NULL, $$SELECT t.harvest('MT', 3, '2026-11-02')$$);
SELECT t.try(NULL, 'a', NULL, $$SELECT t.harvest('MT', 3, '2026-11-03')$$);
SELECT t.try(NULL, 'a', NULL, $$SELECT t.consume('MT', 3)$$);
SELECT t.try(NULL, 'a', NULL, $$SELECT t.harvest('MT', 3, '2026-11-04')$$);
SELECT t.try('possession: delete a consumption while at the limit', 'a', 'blocked',
  $$DELETE FROM public.consumptions WHERE user_id = auth.uid() AND state_id = t.st('MT')$$);
SELECT t.try('possession: shrink a consumption while at the limit', 'a', 'blocked',
  $$UPDATE public.consumptions SET quantity = 1 WHERE user_id = auth.uid() AND state_id = t.st('MT')$$);

-- Eat the birds, then delete the harvest they came from.
SELECT t.try(NULL, 'a', NULL, $$SELECT t.harvest('WY', 3, '2026-11-01')$$);
SELECT t.try(NULL, 'a', NULL, $$SELECT t.consume('WY', 3)$$);
SELECT t.try('possession: delete a harvest already eaten', 'a', 'blocked',
  $$DELETE FROM public.harvest_entries WHERE id = t.entry('WY','2026-11-01')$$);

-- Re-file an entry under a state with room.
SELECT t.try(NULL, 'a', NULL, $$SELECT t.harvest('CO', 3, '2026-11-01')$$);
SELECT t.try('ledger: move an entry to another state', 'a', 'blocked',
  $$UPDATE public.harvest_entries SET state_id = t.st('OK') WHERE id = t.entry('CO','2026-11-01')$$);

-- ---------- Other users ----------
SELECT t.try('rls: distribute against someone else''s entry', 'b', 'blocked',
  $$SELECT t.distribute((SELECT id FROM public.harvest_entries LIMIT 1), 1)$$);
SELECT t.try('rls: log a harvest under someone else''s id', 'b', 'blocked',
  $$INSERT INTO public.harvest_entries (user_id, state_id, species_id, quantity, date)
    VALUES ('00000000-0000-0000-0000-00000000000a', t.st('TX'), t.ph(), 1, '2026-11-01')$$);

-- ---------- Over the limit already (a regulation was lowered) ----------
RESET ROLE;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', false);
SET ROLE authenticated;
SELECT t.try(NULL, 'c', NULL, $$SELECT t.harvest('MO', 3, '2026-11-01')$$);
SELECT t.try(NULL, 'c', NULL, $$SELECT t.harvest('MO', 3, '2026-11-02')$$);
RESET ROLE;
UPDATE regulations SET possession_limit = 4 WHERE state_id = t.st('MO');
SET ROLE authenticated;
SELECT t.try('ok: can still eat down an over-limit freezer', 'c', 'allowed', $$SELECT t.consume('MO', 1)$$);
SELECT t.try('possession: cannot add to an over-limit freezer', 'c', 'blocked', $$SELECT t.harvest('MO', 1, '2026-11-03')$$);

-- ---------- Account deletion must still cascade ----------
RESET ROLE;
SELECT t.try('ok: deleting a user removes their ledger', 'c', 'allowed',
  $$DELETE FROM auth.users WHERE id = '00000000-0000-0000-0000-00000000000c'$$);
