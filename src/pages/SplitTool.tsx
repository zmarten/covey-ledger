import { useState, useEffect, useCallback } from 'react'
import { Users } from 'lucide-react'
import { supabase } from '@/lib/supabase'
import { today, formatDate } from '@/lib/utils'
import type { HarvestEntry } from '@/types/database'
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'

interface SplitRow {
  entry: HarvestEntry
  distribute: number
}

export default function SplitTool() {
  const [entries, setEntries] = useState<HarvestEntry[]>([])
  const [splits, setSplits] = useState<SplitRow[]>([])
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [savedIds, setSavedIds] = useState<Set<string>>(new Set())
  const [error, setError] = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    const { data } = await supabase
      .from('harvest_entries')
      .select('*, states(*), species(*)')
      .eq('date', today())
      .order('created_at', { ascending: false })
    if (data) {
      const entries = data as unknown as HarvestEntry[]
      setEntries(entries)
      setSplits(entries.map(e => ({ entry: e, distribute: 0 })))
    }
    setLoading(false)
  }, [])

  useEffect(() => {
    load()
  }, [load])

  function setDistribute(entryId: string, value: number) {
    setSplits(s => s.map(r => r.entry.id === entryId ? { ...r, distribute: value } : r))
    setError('')
  }

  async function handleSave(row: SplitRow) {
    if (row.distribute <= 0) {
      setError('Distribution quantity must be at least 1.')
      return
    }
    if (row.distribute > row.entry.quantity) {
      setError(`Cannot distribute more than ${row.entry.quantity} (total harvested).`)
      return
    }
    setSaving(true)
    const { error: err } = await supabase.from('distributions').insert({
      harvest_entry_id: row.entry.id,
      quantity_distributed: row.distribute,
    })
    if (err) {
      setError(err.message)
    } else {
      setSavedIds(s => new Set(s).add(row.entry.id))
      setSplits(s => s.map(r => r.entry.id === row.entry.id ? { ...r, distribute: 0 } : r))
    }
    setSaving(false)
  }

  return (
    <div className="page-container section-gap">
      <div className="mb-2">
        <h1 className="text-[32px] font-bold text-olive">End-of-Day Split</h1>
        <p className="text-gray-500 text-sm">
          Distribute birds harvested with others. Only your retained birds count toward possession.
        </p>
      </div>

      <Card className="bg-khaki border-none">
        <div className="flex items-start gap-3">
          <Users size={18} className="text-olive mt-0.5 shrink-0" />
          <p className="text-sm text-olive">
            Enter the number of birds distributed to other hunters for each entry. This reduces your legal possession.
            Distributed birds are logged as an audit trail.
          </p>
        </div>
      </Card>

      {loading && (
        <p className="text-sm text-gray-400">Loading today's entries...</p>
      )}

      {!loading && entries.length === 0 && (
        <Card className="text-center py-8 text-gray-400 text-sm">
          No harvest entries for today. Log birds first.
        </Card>
      )}

      {error && (
        <p className="text-sm text-rust bg-[#fce8e6] border border-rust/30 rounded px-3 py-2">{error}</p>
      )}

      <div className="space-y-3">
        {splits.map((row) => {
          const alreadySaved = savedIds.has(row.entry.id)
          return (
            <Card key={row.entry.id}>
              <CardHeader>
                <CardTitle>
                  {row.entry.species?.name} — {row.entry.states?.name}
                </CardTitle>
                <p className="text-sm text-gray-500 mt-0.5">
                  {formatDate(row.entry.date)} · {row.entry.quantity} harvested
                </p>
              </CardHeader>
              <CardContent>
                {alreadySaved ? (
                  <p className="text-sm text-forest font-medium">Distribution recorded.</p>
                ) : (
                  <div className="flex items-end gap-3">
                    <div className="flex-1">
                      <Input
                        id={`dist-${row.entry.id}`}
                        label="Distribute to others"
                        type="number"
                        min={0}
                        max={row.entry.quantity}
                        value={row.distribute || ''}
                        onChange={(e) => setDistribute(row.entry.id, Number(e.target.value))}
                        placeholder="0"
                      />
                      <p className="text-xs text-gray-400 mt-1">
                        You retain {Math.max(row.entry.quantity - row.distribute, 0)} bird{row.entry.quantity - row.distribute !== 1 ? 's' : ''}.
                      </p>
                    </div>
                    <Button
                      onClick={() => handleSave(row)}
                      disabled={saving || row.distribute <= 0}
                      size="md"
                      variant="outline"
                    >
                      Log Split
                    </Button>
                  </div>
                )}
                {row.entry.notes && (
                  <p className="text-xs text-gray-400 mt-2 italic">{row.entry.notes}</p>
                )}
              </CardContent>
            </Card>
          )
        })}
      </div>
    </div>
  )
}
