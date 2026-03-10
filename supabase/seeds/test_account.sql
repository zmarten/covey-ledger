-- Covey Ledger — Test Account Seed
--
-- STEP 1: Sign up in the app with any real email + password: HuntSafe2026!
-- STEP 2: Replace the email below with whatever you signed up with.
-- STEP 3: Run this script in the Supabase SQL editor.

DO $$
DECLARE
  v_test_email   text := 'zachdmartens.assistant@gmail.com';
  v_user_id      uuid;
  v_ks_id        uuid;
  v_sd_id        uuid;
  v_nd_id        uuid;
  v_pheasant_id  uuid;
  v_quail_id     uuid;
  v_grouse_id    uuid;
  v_partridge_id uuid;
  v_e1_id        uuid := gen_random_uuid();
  v_e2_id        uuid := gen_random_uuid();
  v_e3_id        uuid := gen_random_uuid();
  v_e4_id        uuid := gen_random_uuid();
  v_e5_id        uuid := gen_random_uuid();
  v_e6_id        uuid := gen_random_uuid();
BEGIN

  -- Locate the test user
  SELECT id INTO v_user_id FROM auth.users WHERE email = v_test_email;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User % not found. Sign up in the app first, then re-run this script.', v_test_email;
  END IF;

  -- State IDs
  SELECT id INTO v_ks_id        FROM states WHERE abbreviation = 'KS';
  SELECT id INTO v_sd_id        FROM states WHERE abbreviation = 'SD';
  SELECT id INTO v_nd_id        FROM states WHERE abbreviation = 'ND';

  -- Species IDs
  SELECT id INTO v_pheasant_id  FROM species WHERE name = 'Pheasant';
  SELECT id INTO v_quail_id     FROM species WHERE name = 'Quail';
  SELECT id INTO v_grouse_id    FROM species WHERE name = 'Grouse';
  SELECT id INTO v_partridge_id FROM species WHERE name = 'Partridge';

  -- ----------------------------------------------------------------
  -- REGULATIONS (2025–2026 posted seasons)
  -- ----------------------------------------------------------------
  --
  -- Kansas
  --   Pheasant:  Nov 15, 2025 – Jan 31, 2026  (daily 4, possession 12)
  --   Quail:     Nov 15, 2025 – Jan 31, 2026  (daily 8, possession 24)
  --
  -- South Dakota
  --   Pheasant:  Oct 18, 2025 – Jan 7, 2026   (daily 3, possession 9)
  --     Opens 3rd Saturday of October
  --   Sharp-tailed Grouse: Sep 27, 2025 – Dec 31, 2025 (daily 3, possession 9)
  --     Opens 4th Saturday of September
  --
  -- North Dakota
  --   Pheasant:  Oct 11, 2025 – Jan 4, 2026   (daily 3, possession 9)
  --     Opens 2nd Saturday of October
  --   Gray Partridge (Hun): Sep 6, 2025 – Jan 4, 2026 (daily 5, possession 15)
  --     Opens 1st Saturday of September
  --
  INSERT INTO regulations (state_id, species_id, daily_limit, possession_limit, season_start, season_end)
  VALUES
    (v_ks_id, v_pheasant_id,  4,  12, '2025-11-15', '2026-01-31'),
    (v_ks_id, v_quail_id,     8,  24, '2025-11-15', '2026-01-31'),
    (v_sd_id, v_pheasant_id,  3,   9, '2025-10-18', '2026-01-07'),
    (v_sd_id, v_grouse_id,    3,   9, '2025-09-27', '2025-12-31'),
    (v_nd_id, v_pheasant_id,  3,   9, '2025-10-11', '2026-01-04'),
    (v_nd_id, v_partridge_id, 5,  15, '2025-09-06', '2026-01-04')
  ON CONFLICT (state_id, species_id) DO NOTHING;

  -- ----------------------------------------------------------------
  -- HARVEST ENTRIES (all within open seasons)
  -- ----------------------------------------------------------------

  -- Kansas — Opening weekend, Nov 15–16
  INSERT INTO harvest_entries (id, user_id, state_id, species_id, quantity, date, notes)
  VALUES
    (v_e1_id, v_user_id, v_ks_id, v_pheasant_id, 4, '2025-11-15', 'Opening day, Greenwood County. Dogs worked the draws all morning. Limit by 11am.'),
    (v_e2_id, v_user_id, v_ks_id, v_quail_id,    6, '2025-11-15', 'Bobwhite in the cedar draws. Good covey find on the south ridge.');

  INSERT INTO harvest_entries (id, user_id, state_id, species_id, quantity, date, notes)
  VALUES
    (v_e3_id, v_user_id, v_ks_id, v_pheasant_id, 2, '2025-11-16', 'Wind picked up mid-morning. Shorter day, birds pushed to heavy cover.'),
    (v_e4_id, v_user_id, v_ks_id, v_quail_id,    3, '2025-11-16', 'Same draws, thinned out. Three birds in an hour then called it.');

  -- South Dakota — Late October trip, Oct 25–26 (within Oct 18 – Jan 7 season)
  INSERT INTO harvest_entries (id, user_id, state_id, species_id, quantity, date, notes)
  VALUES
    (v_e5_id, v_user_id, v_sd_id, v_pheasant_id, 3, '2025-10-25', 'Corn stubble fields near Huron. Limit by noon. Three roosters, textbook flushes.'),
    (v_e6_id, v_user_id, v_sd_id, v_pheasant_id, 2, '2025-10-26', 'Cold front moved in overnight. Tougher day. Two roosters late afternoon.');

  -- ----------------------------------------------------------------
  -- DISTRIBUTIONS (end-of-day split with hunting partner)
  -- ----------------------------------------------------------------
  INSERT INTO distributions (harvest_entry_id, quantity_distributed, notes)
  VALUES
    (v_e1_id, 1, 'Split with Jim — he was one short of his limit.'),
    (v_e2_id, 2, 'Jim took 2 quail.');

  -- ----------------------------------------------------------------
  -- CONSUMPTIONS (birds eaten or gifted after the trips)
  -- ----------------------------------------------------------------
  INSERT INTO consumptions (user_id, state_id, species_id, quantity, date, consumption_type, notes)
  VALUES
    (v_user_id, v_ks_id, v_pheasant_id, 2, '2025-11-20', 'consumed', 'Roasted whole with root vegetables.'),
    (v_user_id, v_ks_id, v_quail_id,    4, '2025-11-22', 'consumed', 'Pan-fried, cast iron. Split with family.'),
    (v_user_id, v_sd_id, v_pheasant_id, 1, '2025-11-01', 'gifted',   'One bird to neighbor Dan.');

  RAISE NOTICE 'Seed complete for %', v_test_email;
END;
$$;
