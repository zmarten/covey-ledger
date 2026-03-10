import { useState, useEffect, useCallback } from 'react'
import { Link } from 'react-router-dom'
import { BookOpen, RefreshCw } from 'lucide-react'
import { supabase } from '@/lib/supabase'
import { limitLevel, today } from '@/lib/utils'
import { cn } from '@/lib/utils'
import type { PossessionRow, DailySummaryRow, AppState } from '@/types/database'
import { Card } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Select } from '@/components/ui/select'
import { LimitBar } from '@/components/compliance/LimitBar'
import { Badge } from '@/components/ui/badge'

export default function Dashboard() {
  const [states, setStates] = useState<AppState[]>([])
  const [activeStateId, setActiveStateId] = useState<string>('')
  const [possession, setPossession] = useState<PossessionRow[]>([])
  const [daily, setDaily] = useState<DailySummaryRow[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    supabase.from('states').select('*').order('name').then(({ data }) => {
      if (data) {
        const rows = data as AppState[]
        setStates(rows)
        const saved = localStorage.getItem('covey_active_state')
        setActiveStateId(saved && rows.find(s => s.id === saved) ? saved : (rows[0]?.id ?? ''))
      }
    })
  }, [])

  const load = useCallback(async () => {
    setLoading(true)
    const [possRes, dailyRes] = await Promise.all([
      supabase.rpc('get_possession_summary'),
      supabase.rpc('get_daily_summary', { p_date: today() } as Record<string, unknown>),
    ])
    if (possRes.data) setPossession(possRes.data as PossessionRow[])
    if (dailyRes.data) setDaily(dailyRes.data as DailySummaryRow[])
    setLoading(false)
  }, [])

  useEffect(() => {
    load()
  }, [load])

  function handleStateChange(id: string) {
    setActiveStateId(id)
    localStorage.setItem('covey_active_state', id)
  }

  const activeStateName = states.find(s => s.id === activeStateId)?.name ?? ''

  const dailyForState = daily.filter(d => d.state_id === activeStateId)
  const possessionForState = possession.filter(p => p.state_id === activeStateId)

  // Merge daily + possession for current state
  const speciesMap = new Map<string, { species_name: string; daily_harvested: number; daily_limit: number | null; current_possession: number; possession_limit: number | null }>()
  for (const d of dailyForState) {
    speciesMap.set(d.species_id, {
      species_name: d.species_name,
      daily_harvested: d.daily_harvested,
      daily_limit: d.daily_limit,
      current_possession: 0,
      possession_limit: null,
    })
  }
  for (const p of possessionForState) {
    const existing = speciesMap.get(p.species_id)
    if (existing) {
      existing.current_possession = p.current_possession
      existing.possession_limit = p.possession_limit
    } else {
      speciesMap.set(p.species_id, {
        species_name: p.species_name,
        daily_harvested: 0,
        daily_limit: p.daily_limit,
        current_possession: p.current_possession,
        possession_limit: p.possession_limit,
      })
    }
  }
  const speciesRows = Array.from(speciesMap.values())

  // Freezer summary (all states)
  const allPossessionByState = new Map<string, { state_name: string; state_abbreviation: string; total: number }>()
  for (const p of possession) {
    const existing = allPossessionByState.get(p.state_id)
    if (existing) {
      existing.total += p.current_possession
    } else {
      allPossessionByState.set(p.state_id, {
        state_name: p.state_name,
        state_abbreviation: p.state_abbreviation,
        total: p.current_possession,
      })
    }
  }
  const freezerRows = Array.from(allPossessionByState.values()).filter(r => r.total > 0)

  return (
    <div className="page-container section-gap">
      {/* Header row */}
      <div className="flex items-center justify-between gap-4 flex-wrap">
        <div>
          <h1 className="text-[32px] font-bold text-olive">Today in the Field</h1>
          <p className="text-gray-500 text-sm">{new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })}</p>
        </div>
        <div className="flex items-center gap-3">
          <Select
            options={states.map(s => ({ value: s.id, label: s.name }))}
            value={activeStateId}
            onChange={(e) => handleStateChange(e.target.value)}
            placeholder="Select state"
            className="w-44"
          />
          <button onClick={load} className="text-gray-400 hover:text-olive transition-colors" title="Refresh">
            <RefreshCw size={16} className={loading ? 'animate-spin' : ''} />
          </button>
          <Button asChild variant="accent" size="md">
            <Link to="/harvest"><BookOpen size={15} /> Log Birds</Link>
          </Button>
        </div>
      </div>

      {/* Active state status */}
      {activeStateId && (
        <div>
          <h2 className="text-[24px] font-semibold text-olive mb-4">{activeStateName}</h2>

          {speciesRows.length === 0 ? (
            <Card className="text-center py-8 text-gray-400 text-sm">
              No harvest recorded for {activeStateName} today. <Link to="/harvest" className="text-burnt hover:underline">Log birds.</Link>
            </Card>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              {speciesRows.map((row) => {
                const dailyLevel = limitLevel(row.daily_harvested, row.daily_limit)
                const possLevel = limitLevel(row.current_possession, row.possession_limit)
                const worstLevel = possLevel === 'blocked' || dailyLevel === 'blocked' ? 'blocked'
                  : possLevel === 'warn' || dailyLevel === 'warn' ? 'warn' : 'ok'

                const borderColor = {
                  ok: 'border-[#ccc8be]',
                  warn: 'border-warn',
                  blocked: 'border-rust',
                }[worstLevel]

                return (
                  <Card key={row.species_name} className={cn('border-2', borderColor)}>
                    <div className="flex items-center justify-between mb-3">
                      <h4 className="font-semibold text-olive">{row.species_name}</h4>
                      <Badge variant={worstLevel}>
                        {worstLevel === 'blocked' ? 'At Limit' : worstLevel === 'warn' ? '≥80%' : 'Clear'}
                      </Badge>
                    </div>
                    <div className="space-y-3">
                      <LimitBar
                        used={row.daily_harvested}
                        limit={row.daily_limit}
                        label="Today"
                      />
                      <LimitBar
                        used={row.current_possession}
                        limit={row.possession_limit}
                        label="Possession"
                      />
                    </div>
                  </Card>
                )
              })}
            </div>
          )}
        </div>
      )}

      {/* Freezer summary */}
      {freezerRows.length > 0 && (
        <div>
          <h2 className="text-[24px] font-semibold text-olive mb-4">Possession by State</h2>
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
            {freezerRows.map((row) => (
              <Card key={row.state_name} className="text-center py-4">
                <p className="text-2xl font-bold text-olive tabular-nums">{row.total}</p>
                <p className="text-xs text-gray-500 mt-1">{row.state_name}</p>
              </Card>
            ))}
            <Card className="text-center py-4 bg-khaki">
              <p className="text-2xl font-bold text-olive tabular-nums">
                {freezerRows.reduce((s, r) => s + r.total, 0)}
              </p>
              <p className="text-xs text-gray-500 mt-1">Total in Freezer</p>
            </Card>
          </div>
        </div>
      )}
    </div>
  )
}
