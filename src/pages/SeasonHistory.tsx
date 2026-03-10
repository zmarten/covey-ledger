import { useState, useEffect, useCallback } from 'react'
import { supabase } from '@/lib/supabase'
import { formatDate } from '@/lib/utils'
import type { HarvestEntry, AppState, AppSpecies } from '@/types/database'
import { Select } from '@/components/ui/select'
import { Input } from '@/components/ui/input'
import { Button } from '@/components/ui/button'
import { Card } from '@/components/ui/card'

export default function SeasonHistory() {
  const [entries, setEntries] = useState<HarvestEntry[]>([])
  const [states, setStates] = useState<AppState[]>([])
  const [species, setSpecies] = useState<AppSpecies[]>([])
  const [loading, setLoading] = useState(false)
  const [filterState, setFilterState] = useState('')
  const [filterSpecies, setFilterSpecies] = useState('')
  const [dateFrom, setDateFrom] = useState('')
  const [dateTo, setDateTo] = useState('')

  useEffect(() => {
    Promise.all([
      supabase.from('states').select('*').order('name'),
      supabase.from('species').select('*').order('name'),
    ]).then(([s, sp]) => {
      if (s.data) setStates(s.data)
      if (sp.data) setSpecies(sp.data)
    })
    fetchEntries()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const fetchEntries = useCallback(async () => {
    setLoading(true)
    let query = supabase
      .from('harvest_entries')
      .select('*, states(*), species(*)')
      .order('date', { ascending: false })

    if (filterState) query = query.eq('state_id', filterState)
    if (filterSpecies) query = query.eq('species_id', filterSpecies)
    if (dateFrom) query = query.gte('date', dateFrom)
    if (dateTo) query = query.lte('date', dateTo)

    const { data } = await query
    if (data) setEntries(data as unknown as HarvestEntry[])
    setLoading(false)
  }, [filterState, filterSpecies, dateFrom, dateTo])

  // Totals
  const totalBirds = entries.reduce((s, e) => s + e.quantity, 0)
  const bySpecies = new Map<string, number>()
  for (const e of entries) {
    bySpecies.set(e.species?.name ?? '', (bySpecies.get(e.species?.name ?? '') ?? 0) + e.quantity)
  }

  return (
    <div className="page-container section-gap">
      <h1 className="text-[32px] font-bold text-olive">Season History</h1>

      {/* Filters */}
      <div className="flex flex-wrap gap-3 items-end">
        <div className="w-40">
          <Select
            label="State"
            options={[{ value: '', label: 'All states' }, ...states.map(s => ({ value: s.id, label: s.name }))]}
            value={filterState}
            onChange={(e) => setFilterState(e.target.value)}
          />
        </div>
        <div className="w-40">
          <Select
            label="Species"
            options={[{ value: '', label: 'All species' }, ...species.map(s => ({ value: s.id, label: s.name }))]}
            value={filterSpecies}
            onChange={(e) => setFilterSpecies(e.target.value)}
          />
        </div>
        <div className="w-36">
          <Input
            label="From"
            type="date"
            value={dateFrom}
            onChange={(e) => setDateFrom(e.target.value)}
          />
        </div>
        <div className="w-36">
          <Input
            label="To"
            type="date"
            value={dateTo}
            onChange={(e) => setDateTo(e.target.value)}
          />
        </div>
        <Button onClick={fetchEntries} variant="outline" size="md">Apply</Button>
        <Button
          onClick={() => {
            setFilterState('')
            setFilterSpecies('')
            setDateFrom('')
            setDateTo('')
          }}
          variant="ghost"
          size="md"
        >
          Clear
        </Button>
      </div>

      {/* Summary */}
      {entries.length > 0 && (
        <div className="flex flex-wrap gap-3">
          <Card className="py-3 px-4 flex items-center gap-3">
            <span className="text-2xl font-bold text-olive tabular-nums">{totalBirds}</span>
            <span className="text-sm text-gray-500">total birds</span>
          </Card>
          {Array.from(bySpecies.entries()).map(([name, count]) => (
            <Card key={name} className="py-3 px-4 flex items-center gap-3">
              <span className="text-2xl font-bold text-olive tabular-nums">{count}</span>
              <span className="text-sm text-gray-500">{name.toLowerCase()}</span>
            </Card>
          ))}
        </div>
      )}

      {/* Table */}
      <div className="overflow-x-auto">
        <table className="w-full border-collapse text-sm">
          <thead>
            <tr className="border-b-2 border-khaki">
              <th className="text-left py-3 px-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Date</th>
              <th className="text-left py-3 px-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Species</th>
              <th className="text-left py-3 px-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">State</th>
              <th className="text-right py-3 px-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Qty</th>
              <th className="text-left py-3 px-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Notes</th>
            </tr>
          </thead>
          <tbody>
            {loading && (
              <tr><td colSpan={5} className="py-8 text-center text-gray-400 text-sm">Loading...</td></tr>
            )}
            {!loading && entries.length === 0 && (
              <tr><td colSpan={5} className="py-8 text-center text-gray-400 text-sm">No entries match this filter.</td></tr>
            )}
            {entries.map((entry) => (
              <tr key={entry.id} className="border-b border-khaki hover:bg-white/60 transition-colors min-h-[44px]">
                <td className="py-3 px-3 text-gray-600 whitespace-nowrap">{formatDate(entry.date)}</td>
                <td className="py-3 px-3 font-medium text-olive">{entry.species?.name}</td>
                <td className="py-3 px-3 text-gray-600">{entry.states?.name}</td>
                <td className="py-3 px-3 text-right tabular-nums font-semibold">{entry.quantity}</td>
                <td className="py-3 px-3 text-gray-400 text-xs italic max-w-[200px] truncate">{entry.notes ?? '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
