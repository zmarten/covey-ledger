-- Covey Ledger — Initial Schema
-- Run this in the Supabase SQL editor

-- States table
CREATE TABLE IF NOT EXISTS states (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  abbreviation char(2) NOT NULL UNIQUE,
  created_at timestamptz DEFAULT now()
);

-- Species table
CREATE TABLE IF NOT EXISTS species (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  created_at timestamptz DEFAULT now()
);

-- Regulations table
CREATE TABLE IF NOT EXISTS regulations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  state_id uuid NOT NULL REFERENCES states(id) ON DELETE CASCADE,
  species_id uuid NOT NULL REFERENCES species(id) ON DELETE CASCADE,
  daily_limit integer NOT NULL CHECK (daily_limit > 0),
  possession_limit integer NOT NULL CHECK (possession_limit > 0),
  season_start date,
  season_end date,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(state_id, species_id)
);

-- Harvest entries — immutable ledger of what was harvested
CREATE TABLE IF NOT EXISTS harvest_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  state_id uuid NOT NULL REFERENCES states(id),
  species_id uuid NOT NULL REFERENCES species(id),
  quantity integer NOT NULL CHECK (quantity > 0),
  date date NOT NULL DEFAULT CURRENT_DATE,
  notes text,
  created_at timestamptz DEFAULT now()
);

-- Distributions — birds distributed to other hunters (reduce possession)
CREATE TABLE IF NOT EXISTS distributions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  harvest_entry_id uuid NOT NULL REFERENCES harvest_entries(id) ON DELETE CASCADE,
  quantity_distributed integer NOT NULL CHECK (quantity_distributed > 0),
  notes text,
  created_at timestamptz DEFAULT now()
);

-- Consumptions — birds eaten or gifted (reduce possession)
CREATE TABLE IF NOT EXISTS consumptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  state_id uuid NOT NULL REFERENCES states(id),
  species_id uuid NOT NULL REFERENCES species(id),
  quantity integer NOT NULL CHECK (quantity > 0),
  date date NOT NULL DEFAULT CURRENT_DATE,
  consumption_type text NOT NULL DEFAULT 'consumed' CHECK (consumption_type IN ('consumed', 'gifted')),
  notes text,
  created_at timestamptz DEFAULT now()
);

-- RLS
ALTER TABLE states ENABLE ROW LEVEL SECURITY;
ALTER TABLE species ENABLE ROW LEVEL SECURITY;
ALTER TABLE regulations ENABLE ROW LEVEL SECURITY;
ALTER TABLE harvest_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE distributions ENABLE ROW LEVEL SECURITY;
ALTER TABLE consumptions ENABLE ROW LEVEL SECURITY;

-- States/species/regulations: readable by all authenticated users
CREATE POLICY "states_select" ON states FOR SELECT TO authenticated USING (true);
CREATE POLICY "species_select" ON species FOR SELECT TO authenticated USING (true);
CREATE POLICY "regulations_select" ON regulations FOR SELECT TO authenticated USING (true);
CREATE POLICY "regulations_all" ON regulations FOR ALL TO authenticated USING (true);

-- Harvest entries: owned by user
CREATE POLICY "harvest_entries_all" ON harvest_entries
  FOR ALL TO authenticated USING (auth.uid() = user_id);

-- Distributions: accessible via harvest entry ownership
CREATE POLICY "distributions_all" ON distributions
  FOR ALL TO authenticated USING (
    EXISTS (
      SELECT 1 FROM harvest_entries
      WHERE harvest_entries.id = distributions.harvest_entry_id
        AND harvest_entries.user_id = auth.uid()
    )
  );

-- Consumptions: owned by user
CREATE POLICY "consumptions_all" ON consumptions
  FOR ALL TO authenticated USING (auth.uid() = user_id);

-- Seed states
INSERT INTO states (name, abbreviation) VALUES
  ('Kansas', 'KS'),
  ('South Dakota', 'SD'),
  ('North Dakota', 'ND'),
  ('Nebraska', 'NE'),
  ('Iowa', 'IA'),
  ('Minnesota', 'MN'),
  ('Montana', 'MT'),
  ('Wyoming', 'WY'),
  ('Colorado', 'CO'),
  ('Oklahoma', 'OK'),
  ('Texas', 'TX'),
  ('Missouri', 'MO'),
  ('Idaho', 'ID'),
  ('Oregon', 'OR'),
  ('Washington', 'WA')
ON CONFLICT DO NOTHING;

-- Seed species
INSERT INTO species (name) VALUES
  ('Pheasant'),
  ('Quail'),
  ('Grouse'),
  ('Prairie Chicken'),
  ('Partridge'),
  ('Turkey'),
  ('Woodcock'),
  ('Dove'),
  ('Chukar'),
  ('Sharp-tailed Grouse')
ON CONFLICT DO NOTHING;
