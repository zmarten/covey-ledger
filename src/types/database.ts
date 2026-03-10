// Auto-typed Supabase schema for Covey Ledger
export type Database = {
  public: {
    Tables: {
      states: {
        Row: { id: string; name: string; abbreviation: string; created_at: string }
        Insert: { id?: string; name: string; abbreviation: string }
        Update: { name?: string; abbreviation?: string }
      }
      species: {
        Row: { id: string; name: string; created_at: string }
        Insert: { id?: string; name: string }
        Update: { name?: string }
      }
      regulations: {
        Row: {
          id: string
          state_id: string
          species_id: string
          daily_limit: number
          possession_limit: number
          season_start: string | null
          season_end: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          state_id: string
          species_id: string
          daily_limit: number
          possession_limit: number
          season_start?: string | null
          season_end?: string | null
        }
        Update: {
          daily_limit?: number
          possession_limit?: number
          season_start?: string | null
          season_end?: string | null
          updated_at?: string
        }
      }
      harvest_entries: {
        Row: {
          id: string
          user_id: string
          state_id: string
          species_id: string
          quantity: number
          date: string
          notes: string | null
          created_at: string
        }
        Insert: {
          id?: string
          user_id?: string
          state_id: string
          species_id: string
          quantity: number
          date?: string
          notes?: string | null
        }
        Update: {
          notes?: string | null
        }
      }
      distributions: {
        Row: {
          id: string
          harvest_entry_id: string
          quantity_distributed: number
          notes: string | null
          created_at: string
        }
        Insert: {
          id?: string
          harvest_entry_id: string
          quantity_distributed: number
          notes?: string | null
        }
        Update: {
          quantity_distributed?: number
          notes?: string | null
        }
      }
      consumptions: {
        Row: {
          id: string
          user_id: string
          state_id: string
          species_id: string
          quantity: number
          date: string
          consumption_type: 'consumed' | 'gifted'
          notes: string | null
          created_at: string
        }
        Insert: {
          id?: string
          user_id?: string
          state_id: string
          species_id: string
          quantity: number
          date?: string
          consumption_type?: 'consumed' | 'gifted'
          notes?: string | null
        }
        Update: {
          notes?: string | null
        }
      }
    }
    Functions: {
      validate_harvest_entry: {
        Args: {
          p_state_id: string
          p_species_id: string
          p_quantity: number
          p_date: string
        }
        Returns: {
          blocked: boolean
          dailyRemaining: number | null
          possessionRemaining: number | null
          currentPossession: number
          dailyLimit: number | null
          possessionLimit: number | null
          explanation: string
        }
      }
      get_possession_summary: {
        Args: Record<string, never>
        Returns: Array<{
          state_id: string
          species_id: string
          state_name: string
          state_abbreviation: string
          species_name: string
          total_harvested: number
          total_distributed: number
          total_consumed: number
          current_possession: number
          possession_limit: number | null
          daily_limit: number | null
        }>
      }
      get_daily_summary: {
        Args: { p_date?: string }
        Returns: Array<{
          state_id: string
          species_id: string
          state_name: string
          state_abbreviation: string
          species_name: string
          daily_harvested: number
          daily_limit: number | null
        }>
      }
    }
  }
}

// App-level types
export interface AppState {
  id: string
  name: string
  abbreviation: string
}

export interface AppSpecies {
  id: string
  name: string
}

export interface Regulation {
  id: string
  state_id: string
  species_id: string
  daily_limit: number
  possession_limit: number
  season_start: string | null
  season_end: string | null
  states?: AppState
  species?: AppSpecies
}

export interface HarvestEntry {
  id: string
  user_id: string
  state_id: string
  species_id: string
  quantity: number
  date: string
  notes: string | null
  created_at: string
  states?: AppState
  species?: AppSpecies
}

export interface Distribution {
  id: string
  harvest_entry_id: string
  quantity_distributed: number
  notes: string | null
  created_at: string
}

export interface Consumption {
  id: string
  user_id: string
  state_id: string
  species_id: string
  quantity: number
  date: string
  consumption_type: 'consumed' | 'gifted'
  notes: string | null
  created_at: string
}

export interface ComplianceResult {
  blocked: boolean
  dailyRemaining: number | null
  possessionRemaining: number | null
  currentPossession: number
  dailyLimit: number | null
  possessionLimit: number | null
  explanation: string
}

export interface PossessionRow {
  state_id: string
  species_id: string
  state_name: string
  state_abbreviation: string
  species_name: string
  total_harvested: number
  total_distributed: number
  total_consumed: number
  current_possession: number
  possession_limit: number | null
  daily_limit: number | null
}

export interface DailySummaryRow {
  state_id: string
  species_id: string
  state_name: string
  state_abbreviation: string
  species_name: string
  daily_harvested: number
  daily_limit: number | null
}
