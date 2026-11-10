-- Covey Ledger — Per-user regulations
--
-- Regulations were one shared table that any signed-in user could edit or
-- delete, so one hunter could change everyone's limits. Each user now keeps
-- their own regulations and can neither see nor change anyone else's.
--
-- Existing rows: every current user gets their own copy of the shared set, so
-- nobody's limits change when this is applied. Users who sign up later start
-- with an empty table and add their own.

ALTER TABLE regulations
  ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE;

-- The old one-row-per-state/species rule has to go before rows can be copied.
ALTER TABLE regulations DROP CONSTRAINT IF EXISTS regulations_state_id_species_id_key;

INSERT INTO regulations
  (user_id, state_id, species_id, daily_limit, possession_limit, season_start, season_end, created_at, updated_at)
SELECT u.id, r.state_id, r.species_id, r.daily_limit, r.possession_limit,
       r.season_start, r.season_end, r.created_at, r.updated_at
FROM regulations r
CROSS JOIN auth.users u
WHERE r.user_id IS NULL;

DELETE FROM regulations WHERE user_id IS NULL;

ALTER TABLE regulations
  ALTER COLUMN user_id SET NOT NULL,
  ALTER COLUMN user_id SET DEFAULT auth.uid(),
  ADD CONSTRAINT regulations_user_state_species_key UNIQUE (user_id, state_id, species_id);

-- Owner-only access. WITH CHECK stops a row being written under another id.
DROP POLICY IF EXISTS "regulations_select" ON regulations;
DROP POLICY IF EXISTS "regulations_all" ON regulations;
CREATE POLICY "regulations_own" ON regulations
  FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ------------------------------------------------------------
-- Every function that looks up a regulation now looks up the
-- caller's own. Bodies are otherwise unchanged.
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
  WHERE user_id = p_user_id AND state_id = p_state_id AND species_id = p_species_id;
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

CREATE OR REPLACE FUNCTION validate_harvest_entry(
  p_state_id uuid,
  p_species_id uuid,
  p_quantity integer,
  p_date date
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_reg regulations%ROWTYPE;
  v_daily_harvested integer;
  v_total_harvested integer;
  v_total_distributed integer;
  v_total_consumed integer;
  v_current_possession integer;
  v_daily_remaining integer;
  v_possession_remaining integer;
  v_blocked boolean := false;
  v_explanation text := '';
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('blocked', true, 'explanation', 'Not authenticated.');
  END IF;

  -- Fetch the caller's regulation for this state/species
  SELECT * INTO v_reg
  FROM regulations
  WHERE user_id = v_user_id AND state_id = p_state_id AND species_id = p_species_id;

  IF NOT FOUND THEN
    -- No regulation on file — allow but note it
    RETURN jsonb_build_object(
      'blocked', false,
      'dailyRemaining', null,
      'possessionRemaining', null,
      'currentPossession', 0,
      'dailyLimit', null,
      'possessionLimit', null,
      'explanation', 'No regulation on file for this state/species. Entry logged without limit enforcement.'
    );
  END IF;

  -- Step 1: Daily limit check
  SELECT COALESCE(SUM(quantity), 0) INTO v_daily_harvested
  FROM harvest_entries
  WHERE user_id = v_user_id
    AND state_id = p_state_id
    AND species_id = p_species_id
    AND date = p_date;

  v_daily_remaining := v_reg.daily_limit - v_daily_harvested;

  IF p_quantity > v_daily_remaining THEN
    v_blocked := true;
    v_explanation := format(
      'Daily limit: %s. Harvested today: %s. Remaining: %s.',
      v_reg.daily_limit, v_daily_harvested, GREATEST(v_daily_remaining, 0)
    );
  END IF;

  -- Step 2: Possession check
  SELECT COALESCE(SUM(quantity), 0) INTO v_total_harvested
  FROM harvest_entries
  WHERE user_id = v_user_id
    AND state_id = p_state_id
    AND species_id = p_species_id;

  SELECT COALESCE(SUM(d.quantity_distributed), 0) INTO v_total_distributed
  FROM distributions d
  JOIN harvest_entries h ON d.harvest_entry_id = h.id
  WHERE h.user_id = v_user_id
    AND h.state_id = p_state_id
    AND h.species_id = p_species_id;

  SELECT COALESCE(SUM(quantity), 0) INTO v_total_consumed
  FROM consumptions
  WHERE user_id = v_user_id
    AND state_id = p_state_id
    AND species_id = p_species_id;

  v_current_possession := v_total_harvested - v_total_distributed - v_total_consumed;
  v_possession_remaining := v_reg.possession_limit - v_current_possession;

  IF p_quantity > v_possession_remaining THEN
    v_blocked := true;
    IF v_explanation != '' THEN v_explanation := v_explanation || ' '; END IF;
    v_explanation := v_explanation || format(
      'Possession limit: %s. Current possession: %s. Remaining: %s.',
      v_reg.possession_limit, v_current_possession, GREATEST(v_possession_remaining, 0)
    );
  END IF;

  RETURN jsonb_build_object(
    'blocked', v_blocked,
    'dailyRemaining', GREATEST(v_daily_remaining, 0),
    'possessionRemaining', GREATEST(v_possession_remaining, 0),
    'currentPossession', v_current_possession,
    'dailyLimit', v_reg.daily_limit,
    'possessionLimit', v_reg.possession_limit,
    'explanation', v_explanation
  );
END;
$$;

CREATE OR REPLACE FUNCTION get_possession_summary()
RETURNS TABLE (
  state_id uuid,
  species_id uuid,
  state_name text,
  state_abbreviation char(2),
  species_name text,
  total_harvested bigint,
  total_distributed bigint,
  total_consumed bigint,
  current_possession bigint,
  possession_limit integer,
  daily_limit integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  RETURN QUERY
  WITH harvested AS (
    SELECT h.state_id, h.species_id, SUM(h.quantity)::bigint AS total
    FROM harvest_entries h
    WHERE h.user_id = v_user_id
    GROUP BY h.state_id, h.species_id
  ),
  distributed AS (
    SELECT h.state_id, h.species_id, COALESCE(SUM(d.quantity_distributed), 0)::bigint AS total
    FROM harvest_entries h
    JOIN distributions d ON d.harvest_entry_id = h.id
    WHERE h.user_id = v_user_id
    GROUP BY h.state_id, h.species_id
  ),
  consumed AS (
    SELECT c.state_id, c.species_id, SUM(c.quantity)::bigint AS total
    FROM consumptions c
    WHERE c.user_id = v_user_id
    GROUP BY c.state_id, c.species_id
  )
  SELECT
    st.id                                                          AS state_id,
    sp.id                                                          AS species_id,
    st.name                                                        AS state_name,
    st.abbreviation                                                AS state_abbreviation,
    sp.name                                                        AS species_name,
    COALESCE(hv.total, 0)                                         AS total_harvested,
    COALESCE(dv.total, 0)                                         AS total_distributed,
    COALESCE(cv.total, 0)                                         AS total_consumed,
    COALESCE(hv.total, 0) - COALESCE(dv.total, 0) - COALESCE(cv.total, 0) AS current_possession,
    r.possession_limit,
    r.daily_limit
  FROM harvested hv
  JOIN states st ON st.id = hv.state_id
  JOIN species sp ON sp.id = hv.species_id
  LEFT JOIN distributed dv ON dv.state_id = hv.state_id AND dv.species_id = hv.species_id
  LEFT JOIN consumed cv ON cv.state_id = hv.state_id AND cv.species_id = hv.species_id
  LEFT JOIN regulations r ON r.user_id = v_user_id AND r.state_id = hv.state_id AND r.species_id = hv.species_id
  ORDER BY st.name, sp.name;
END;
$$;

CREATE OR REPLACE FUNCTION get_daily_summary(p_date date DEFAULT CURRENT_DATE)
RETURNS TABLE (
  state_id uuid,
  species_id uuid,
  state_name text,
  state_abbreviation char(2),
  species_name text,
  daily_harvested bigint,
  daily_limit integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  RETURN QUERY
  SELECT
    st.id       AS state_id,
    sp.id       AS species_id,
    st.name     AS state_name,
    st.abbreviation AS state_abbreviation,
    sp.name     AS species_name,
    SUM(h.quantity)::bigint AS daily_harvested,
    r.daily_limit
  FROM harvest_entries h
  JOIN states st ON st.id = h.state_id
  JOIN species sp ON sp.id = h.species_id
  LEFT JOIN regulations r ON r.user_id = v_user_id AND r.state_id = h.state_id AND r.species_id = h.species_id
  WHERE h.user_id = v_user_id AND h.date = p_date
  GROUP BY st.id, st.name, st.abbreviation, sp.id, sp.name, r.daily_limit
  ORDER BY st.name, sp.name;
END;
$$;
