import { useState, useEffect, useCallback } from 'react'
import { supabase } from '@/lib/supabase'
import { useAuth } from '@/hooks/useAuth'
import { today, limitLevel } from '@/lib/utils'
import { cn } from '@/lib/utils'
import type { PossessionRow, AppState, AppSpecies } from '@/types/database'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Select } from '@/components/ui/select'
import { LimitBar } from '@/components/compliance/LimitBar'
import { Dialog, DialogContent, DialogClose } from '@/components/ui/dialog'
import { Card } from '@/components/ui/card'

interface ConsumeForm {
  state_id: string
  species_id: string
  quantity: string
  type: 'consumed' | 'gifted'
  notes: string
}

const EMPTY_FORM: ConsumeForm = {
  state_id: '',
  species_id: '',
  quantity: '',
  type: 'consumed',
  notes: '',
}

export default function FreezerInventory() {
  const { user } = useAuth()
  const [possession, setPossession] = useState<PossessionRow[]>([])
  const [states, setStates] = useState<AppState[]>([])
  const [species, setSpecies] = useState<AppSpecies[]>([])
  const [loading, setLoading] = useState(true)
  const [dialogOpen, setDialogOpen] = useState(false)
  const [form, setForm] = useState<ConsumeForm>(EMPTY_FORM)
  const [formErrors, setFormErrors] = useState<Partial<ConsumeForm>>({})
  const [saving, setSaving] = useState(false)
  const [successMsg, setSuccessMsg] = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    const { data } = await supabase.rpc('get_possession_summary')
    if (data) setPossession(data as PossessionRow[])
    setLoading(false)
  }, [])

  useEffect(() => {
    Promise.all([
      supabase.from('states').select('*').order('name'),
      supabase.from('species').select('*').order('name'),
    ]).then(([s, sp]) => {
      if (s.data) setStates(s.data)
      if (sp.data) setSpecies(sp.data)
    })
    load()
  }, [load])

  function openConsume(row?: PossessionRow) {
    setForm({
      ...EMPTY_FORM,
      state_id: row?.state_id ?? '',
      species_id: row?.species_id ?? '',
    })
    setFormErrors({})
    setSuccessMsg('')
    setDialogOpen(true)
  }

  function setField(field: keyof ConsumeForm, value: string) {
    setForm(f => ({ ...f, [field]: value }))
    setFormErrors(e => ({ ...e, [field]: '' }))
  }

  async function handleConsume() {
    const e: Partial<ConsumeForm> = {}
    if (!form.state_id) e.state_id = 'Required'
    if (!form.species_id) e.species_id = 'Required'
    if (!form.quantity || Number(form.quantity) < 1) e.quantity = 'Must be at least 1'
    setFormErrors(e)
    if (Object.keys(e).length) return

    setSaving(true)
    const { error } = await supabase.from('consumptions').insert({
      user_id: user!.id,
      state_id: form.state_id,
      species_id: form.species_id,
      quantity: Number(form.quantity),
      date: today(),
      consumption_type: form.type,
      notes: form.notes || null,
    })

    if (error) {
      setFormErrors({ quantity: error.message })
    } else {
      setSuccessMsg('Freezer updated.')
      load()
      setTimeout(() => setDialogOpen(false), 1200)
    }
    setSaving(false)
  }

  // Summary
  const totalPossession = possession.reduce((s, r) => s + r.current_possession, 0)
  const byState = new Map<string, { name: string; total: number }>()
  for (const r of possession) {
    const ex = byState.get(r.state_id)
    if (ex) ex.total += r.current_possession
    else byState.set(r.state_id, { name: r.state_name, total: r.current_possession })
  }

  return (
    <div className="page-container section-gap">
      <div className="flex items-center justify-between gap-4 flex-wrap">
        <h1 className="text-[32px] font-bold text-olive">Freezer Inventory</h1>
        <Button onClick={() => openConsume()} size="md" variant="outline">
          Mark Consumed / Gifted
        </Button>
      </div>

      {/* Summary cards */}
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
        {Array.from(byState.values()).filter(r => r.total > 0).map((row) => (
          <Card key={row.name} className="text-center py-4">
            <p className="text-2xl font-bold text-olive tabular-nums">{row.total}</p>
            <p className="text-xs text-gray-500 mt-1">{row.name}</p>
          </Card>
        ))}
        <Card className="text-center py-4 bg-khaki border-none">
          <p className="text-2xl font-bold text-olive tabular-nums">{totalPossession}</p>
          <p className="text-xs text-gray-500 mt-1">Total Possession</p>
        </Card>
      </div>

      {/* Table */}
      <div className="overflow-x-auto -mx-4 md:mx-0 px-4 md:px-0">
        <table className="w-full min-w-[640px] border-collapse text-sm">
          <thead>
            <tr className="border-b-2 border-khaki">
              {['Species', 'State', 'Harvested', 'Distributed', 'Consumed', 'Possession', 'Limit', 'Status', ''].map(h => (
                <th
                  key={h}
                  className={cn(
                    'py-3 px-3 text-xs font-semibold text-gray-500 uppercase tracking-wide',
                    ['Harvested', 'Distributed', 'Consumed', 'Possession', 'Limit'].includes(h) ? 'text-right' : 'text-left'
                  )}
                >
                  {h}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {loading && (
              <tr><td colSpan={9} className="py-8 text-center text-gray-400 text-sm">Loading...</td></tr>
            )}
            {!loading && possession.length === 0 && (
              <tr><td colSpan={9} className="py-8 text-center text-gray-400 text-sm">No harvest recorded yet.</td></tr>
            )}
            {possession.map((row) => {
              const level = limitLevel(row.current_possession, row.possession_limit)
              return (
                <tr key={`${row.state_id}-${row.species_id}`} className="border-b border-khaki hover:bg-white/60 transition-colors">
                  <td className="py-3 px-3 font-medium text-olive">{row.species_name}</td>
                  <td className="py-3 px-3 text-gray-600">{row.state_abbreviation}</td>
                  <td className="py-3 px-3 text-right tabular-nums">{row.total_harvested}</td>
                  <td className="py-3 px-3 text-right tabular-nums text-gray-500">{row.total_distributed}</td>
                  <td className="py-3 px-3 text-right tabular-nums text-gray-500">{row.total_consumed}</td>
                  <td className="py-3 px-3 text-right">
                    <span className={cn(
                      'tabular-nums font-semibold',
                      level === 'blocked' && 'text-rust',
                      level === 'warn' && 'text-warn',
                      level === 'ok' && 'text-forest'
                    )}>
                      {row.current_possession}
                    </span>
                  </td>
                  <td className="py-3 px-3 text-right tabular-nums text-gray-500">
                    {row.possession_limit ?? '—'}
                  </td>
                  <td className="py-3 px-3">
                    <div className="w-28">
                      <LimitBar used={row.current_possession} limit={row.possession_limit} showNumbers={false} />
                    </div>
                  </td>
                  <td className="py-3 px-3">
                    <button
                      onClick={() => openConsume(row)}
                      className="text-xs text-burnt hover:underline whitespace-nowrap"
                    >
                      Adjust
                    </button>
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>

      {/* Consume/Gift Dialog */}
      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent title="Mark Consumed / Gifted" description="Reduces legal possession.">
          {successMsg ? (
            <p className="text-sm text-forest font-medium py-2">{successMsg}</p>
          ) : (
            <div className="space-y-4">
              <Select
                id="con-state"
                label="State"
                options={states.map(s => ({ value: s.id, label: s.name }))}
                value={form.state_id}
                onChange={(e) => setField('state_id', e.target.value)}
                placeholder="Select state"
                error={formErrors.state_id}
              />
              <Select
                id="con-species"
                label="Species"
                options={species.map(s => ({ value: s.id, label: s.name }))}
                value={form.species_id}
                onChange={(e) => setField('species_id', e.target.value)}
                placeholder="Select species"
                error={formErrors.species_id}
              />
              <Input
                id="con-qty"
                label="Quantity"
                type="number"
                min={1}
                value={form.quantity}
                onChange={(e) => setField('quantity', e.target.value)}
                error={formErrors.quantity}
              />
              <Select
                id="con-type"
                label="Type"
                options={[
                  { value: 'consumed', label: 'Consumed (eaten)' },
                  { value: 'gifted', label: 'Gifted' },
                ]}
                value={form.type}
                onChange={(e) => setField('type', e.target.value)}
              />
              <div className="flex flex-col gap-1">
                <label htmlFor="con-notes" className="text-sm font-medium text-olive">Notes (optional)</label>
                <textarea
                  id="con-notes"
                  value={form.notes}
                  onChange={(e) => setField('notes', e.target.value)}
                  rows={2}
                  className="w-full rounded border border-[#ccc8be] bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-olive focus:border-olive resize-none"
                />
              </div>
              <div className="flex gap-3 pt-2">
                <Button onClick={handleConsume} disabled={saving} className="flex-1">
                  {saving ? 'Saving...' : 'Save'}
                </Button>
                <DialogClose asChild>
                  <Button variant="ghost">Cancel</Button>
                </DialogClose>
              </div>
            </div>
          )}
        </DialogContent>
      </Dialog>
    </div>
  )
}
