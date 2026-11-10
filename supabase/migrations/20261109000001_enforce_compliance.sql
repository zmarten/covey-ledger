-- Covey Ledger — Enforce compliance in the database
--
-- Until now validate_harvest_entry was only a preview: the app called it and
-- then inserted the row in a separate request, so nothing stopped a write that
-- skipped the check. These triggers make the database itself refuse any write
-- that would break a limit, whichever table it arrives through.
--
-- Rules, per user / state / species:
--   * a day's harvest may not exceed the daily limit
--   * possession (harvested - distributed - consumed) may not rise above the
--     possession limit, and may not fall below zero
--   * an entry cannot have more birds distributed than it holds
--   * an entry's owner, state and species are fixed once logged
-- A write is only refused for the direction it moves possession, so a freezer
-- that is already over the limit (say a regulation was lowered) can still be
-- eaten down. State/species pairs with no regulation stay unenforced, as before.
--
-- To correct data by hand in the SQL editor, wrap the statements in
--   SET session_replication_role = replica;  ...  SET session_replication_role = DEFAULT;

-- ------------------------------------------------------------
-- covey_lock: one writer at a time per user/state/species, held until the
-- transaction ends. Without it, two requests sent together would each see the
-- other's birds as not yet logged.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION covey_lock(p_user_id uuid, p_state_id uuid, p_species_id uuid)
RETURNS void
LANGUAGE sql
SET search_path = public, pg_temp
AS $$
  SELECT pg_advisory_xact_lock(
    hashtextextended(p_user_id::text || ':' || p_state_id::text || ':' || p_species_id::text, 0)
  );
$$;

-- ------------------------------------------------------------
-- covey_check: the single place the rules are evaluated.
-- Runs after the row change, so the totals already include it.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION covey_check(
  p_user_id uuid,
  p_state_id uuid,
  p_species_id uuid,
  p_check_ceiling boolean,   -- possession may have gone up
  p_check_floor boolean,     -- possession may have gone down
  p_daily_date date          -- day to check against the daily limit, or NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_reg regulations%ROWTYPE;
  v_possession integer;
  v_daily integer;
BEGIN
  -- The account itself is being deleted; its rows are all going away.
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_user_id) THEN
    RETURN;
  END IF;

  PERFORM covey_lock(p_user_id, p_state_id, p_species_id);

  SELECT
      COALESCE((SELECT SUM(h.quantity) FROM harvest_entries h
                WHERE h.user_id = p_user_id AND h.state_id = p_state_id AND h.species_id = p_species_id), 0)
    - COALESCE((SELECT SUM(d.quantity_distributed) FROM distributions d
                JOIN harvest_entries h ON h.id = d.harvest_entry_id
                WHERE h.user_id = p_user_id AND h.state_id = p_state_id AND h.species_id = p_species_id), 0)
    - COALESCE((SELECT SUM(c.quantity) FROM consumptions c
                WHERE c.user_id = p_user_id AND c.state_id = p_state_id AND c.species_id = p_species_id), 0)
  INTO v_possession;

  IF p_check_floor AND v_possession < 0 THEN
    RAISE EXCEPTION 'Not enough birds in possession: this would leave you % short for this state and species.',
      -v_possession USING ERRCODE = 'check_violation';
  END IF;

  SELECT * INTO v_reg FROM regulations
  WHERE state_id = p_state_id AND species_id = p_species_id;
  IF NOT FOUND THEN
    RETURN;
  END IF;

  IF p_daily_date IS NOT NULL THEN
    SELECT COALESCE(SUM(quantity), 0) INTO v_daily
    FROM harvest_entries
    WHERE user_id = p_user_id AND state_id = p_state_id
      AND species_id = p_species_id AND date = p_daily_date;

    IF v_daily > v_reg.daily_limit THEN
      RAISE EXCEPTION 'Daily limit exceeded: limit is %, this would bring % to %.',
        v_reg.daily_limit, to_char(p_daily_date, 'Mon FMDD'), v_daily
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  IF p_check_ceiling AND v_possession > v_reg.possession_limit THEN
    RAISE EXCEPTION 'Possession limit exceeded: limit is %, this would bring your possession to %.',
      v_reg.possession_limit, v_possession USING ERRCODE = 'check_violation';
  END IF;
END;
$$;

-- ------------------------------------------------------------
-- harvest_entries
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION covey_harvest_entries_enforce()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_distributed integer;
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM covey_check(NEW.user_id, NEW.state_id, NEW.species_id, true, false, NEW.date);

  ELSIF TG_OP = 'DELETE' THEN
    PERFORM covey_check(OLD.user_id, OLD.state_id, OLD.species_id, false, true, NULL);

  ELSE
    IF (NEW.user_id, NEW.state_id, NEW.species_id) IS DISTINCT FROM (OLD.user_id, OLD.state_id, OLD.species_id) THEN
      RAISE EXCEPTION 'A harvest entry''s owner, state and species cannot be changed. Delete it and log a new one.'
        USING ERRCODE = 'check_violation';
    END IF;

    PERFORM covey_lock(NEW.user_id, NEW.state_id, NEW.species_id);

    SELECT COALESCE(SUM(quantity_distributed), 0) INTO v_distributed
    FROM distributions WHERE harvest_entry_id = NEW.id;
    IF v_distributed > NEW.quantity THEN
      RAISE EXCEPTION 'This entry already has % birds distributed; it cannot be reduced to %.',
        v_distributed, NEW.quantity USING ERRCODE = 'check_violation';
    END IF;

    PERFORM covey_check(
      NEW.user_id, NEW.state_id, NEW.species_id,
      NEW.quantity > OLD.quantity,
      NEW.quantity < OLD.quantity,
      CASE WHEN NEW.quantity > OLD.quantity OR NEW.date <> OLD.date THEN NEW.date END
    );
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS covey_enforce ON harvest_entries;
CREATE TRIGGER covey_enforce
  AFTER INSERT OR UPDATE OR DELETE ON harvest_entries
  FOR EACH ROW EXECUTE FUNCTION covey_harvest_entries_enforce();

-- ------------------------------------------------------------
-- distributions
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION covey_distributions_enforce()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_entry harvest_entries%ROWTYPE;
  v_distributed integer;
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.harvest_entry_id <> OLD.harvest_entry_id THEN
    RAISE EXCEPTION 'A distribution cannot be moved to another harvest entry. Delete it and add a new one.'
      USING ERRCODE = 'check_violation';
  END IF;

  SELECT * INTO v_entry FROM harvest_entries
  WHERE id = CASE WHEN TG_OP = 'DELETE' THEN OLD.harvest_entry_id ELSE NEW.harvest_entry_id END;
  IF NOT FOUND THEN
    RETURN NULL;  -- the entry itself was deleted; its own trigger does the checking
  END IF;

  IF TG_OP = 'DELETE' THEN
    PERFORM covey_check(v_entry.user_id, v_entry.state_id, v_entry.species_id, true, false, NULL);
    RETURN NULL;
  END IF;

  PERFORM covey_lock(v_entry.user_id, v_entry.state_id, v_entry.species_id);
  -- Read the entry again now that the lock is held, in case it was just edited.
  SELECT * INTO v_entry FROM harvest_entries WHERE id = v_entry.id;

  SELECT COALESCE(SUM(quantity_distributed), 0) INTO v_distributed
  FROM distributions WHERE harvest_entry_id = v_entry.id;
  IF v_distributed > v_entry.quantity THEN
    RAISE EXCEPTION 'Cannot distribute % birds from an entry of %.',
      v_distributed, v_entry.quantity USING ERRCODE = 'check_violation';
  END IF;

  PERFORM covey_check(
    v_entry.user_id, v_entry.state_id, v_entry.species_id,
    TG_OP = 'UPDATE' AND NEW.quantity_distributed < OLD.quantity_distributed,
    TG_OP = 'INSERT' OR NEW.quantity_distributed > OLD.quantity_distributed,
    NULL
  );
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS covey_enforce ON distributions;
CREATE TRIGGER covey_enforce
  AFTER INSERT OR UPDATE OR DELETE ON distributions
  FOR EACH ROW EXECUTE FUNCTION covey_distributions_enforce();

-- ------------------------------------------------------------
-- consumptions
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION covey_consumptions_enforce()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM covey_check(NEW.user_id, NEW.state_id, NEW.species_id, false, true, NULL);

  ELSIF TG_OP = 'DELETE' THEN
    PERFORM covey_check(OLD.user_id, OLD.state_id, OLD.species_id, true, false, NULL);

  ELSE
    IF (NEW.user_id, NEW.state_id, NEW.species_id) IS DISTINCT FROM (OLD.user_id, OLD.state_id, OLD.species_id) THEN
      RAISE EXCEPTION 'A consumption record''s owner, state and species cannot be changed. Delete it and add a new one.'
        USING ERRCODE = 'check_violation';
    END IF;
    PERFORM covey_check(
      NEW.user_id, NEW.state_id, NEW.species_id,
      NEW.quantity < OLD.quantity,
      NEW.quantity > OLD.quantity,
      NULL
    );
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS covey_enforce ON consumptions;
CREATE TRIGGER covey_enforce
  AFTER INSERT OR UPDATE OR DELETE ON consumptions
  FOR EACH ROW EXECUTE FUNCTION covey_consumptions_enforce();

-- ------------------------------------------------------------
-- Function hardening
-- ------------------------------------------------------------
-- The enforcement functions take a user id as an argument, so they must not be
-- callable through the API. Triggers still run them.
REVOKE ALL ON FUNCTION covey_lock(uuid, uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION covey_check(uuid, uuid, uuid, boolean, boolean, date) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION covey_harvest_entries_enforce() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION covey_distributions_enforce() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION covey_consumptions_enforce() FROM PUBLIC, anon, authenticated;

-- Existing SECURITY DEFINER functions: pin the search path and stop serving
-- them to signed-out callers.
ALTER FUNCTION validate_harvest_entry(uuid, uuid, integer, date) SET search_path = public, pg_temp;
ALTER FUNCTION get_possession_summary() SET search_path = public, pg_temp;
ALTER FUNCTION get_daily_summary(date) SET search_path = public, pg_temp;
REVOKE ALL ON FUNCTION validate_harvest_entry(uuid, uuid, integer, date) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION get_possession_summary() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION get_daily_summary(date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION validate_harvest_entry(uuid, uuid, integer, date) TO authenticated;
GRANT EXECUTE ON FUNCTION get_possession_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION get_daily_summary(date) TO authenticated;
