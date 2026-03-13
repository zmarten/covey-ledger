import { useState, useEffect, useCallback } from 'react'
import { Plus, Pencil, Trash2 } from 'lucide-react'
import { supabase } from '@/lib/supabase'
import type { Regulation, AppState, AppSpecies } from '@/types/database'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Select } from '@/components/ui/select'
import { Dialog, DialogContent, DialogClose } from '@/components/ui/dialog'

interface FormState {
  state_id: string
  species_id: string
  daily_limit: string
  possession_limit: string
  season_start: string
  season_end: string
}

const EMPTY_FORM: FormState = {
  state_id: '',
  species_id: '',
  daily_limit: '',
  possession_limit: '',
  season_start: '',
  season_end: '',
}

export default function StateRegulations() {
  const [regulations, setRegulations] = useState<Regulation[]>([])
  const [states, setStates] = useState<AppState[]>([])
  const [species, setSpecies] = useState<AppSpecies[]>([])
  const [filterState, setFilterState] = useState('')
  const [open, setOpen] = useState(false)
  const [editId, setEditId] = useState<string | null>(null)
  const [form, setForm] = useState<FormState>(EMPTY_FORM)
  const [errors, setErrors] = useState<Partial<FormState>>({})
  const [saving, setSaving] = useState(false)
  const [deleteId, setDeleteId] = useState<string | null>(null)

  const load = useCallback(async () => {
    const { data } = await supabase
      .from('regulations')
      .select('*, states(*), species(*)')
      .order('states(name)')
    if (data) setRegulations(data as unknown as Regulation[])
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

  function openAdd() {
    setEditId(null)
    setForm(EMPTY_FORM)
    setErrors({})
    setOpen(true)
  }

  function openEdit(reg: Regulation) {
    setEditId(reg.id)
    setForm({
      state_id: reg.state_id,
      species_id: reg.species_id,
      daily_limit: String(reg.daily_limit),
      possession_limit: String(reg.possession_limit),
      season_start: reg.season_start ?? '',
      season_end: reg.season_end ?? '',
    })
    setErrors({})
    setOpen(true)
  }

  function set(field: keyof FormState, value: string) {
    setForm(f => ({ ...f, [field]: value }))
    setErrors(e => ({ ...e, [field]: '' }))
  }

  function validate() {
    const e: Partial<FormState> = {}
    if (!form.state_id) e.state_id = 'Required'
    if (!form.species_id) e.species_id = 'Required'
    if (!form.daily_limit || Number(form.daily_limit) < 1) e.daily_limit = 'Must be ≥ 1'
    if (!form.possession_limit || Number(form.possession_limit) < 1) e.possession_limit = 'Must be ≥ 1'
    setErrors(e)
    return Object.keys(e).length === 0
  }

  async function handleSave() {
    if (!validate()) return
    setSaving(true)

    const payload = {
      state_id: form.state_id,
      species_id: form.species_id,
      daily_limit: Number(form.daily_limit),
      possession_limit: Number(form.possession_limit),
      season_start: form.season_start || null,
      season_end: form.season_end || null,
      updated_at: new Date().toISOString(),
    }

    let error
    if (editId) {
      const res = await supabase.from('regulations').update(payload).eq('id', editId)
      error = res.error
    } else {
      const res = await supabase.from('regulations').insert(payload)
      error = res.error
    }

    if (!error) {
      setOpen(false)
      load()
    } else {
      setErrors({ state_id: error.message })
    }
    setSaving(false)
  }

  async function handleDelete(id: string) {
    await supabase.from('regulations').delete().eq('id', id)
    setDeleteId(null)
    load()
  }

  const filtered = filterState
    ? regulations.filter(r => r.state_id === filterState)
    : regulations

  return (
    <div className="page-container section-gap">
      <div className="flex items-start justify-between gap-4 flex-wrap">
        <h1 className="text-[32px] font-bold text-olive">Regulations</h1>
        <div className="flex items-center gap-3 w-full md:w-auto">
          <Select
            options={[{ value: '', label: 'All states' }, ...states.map(s => ({ value: s.id, label: s.name }))]}
            value={filterState}
            onChange={(e) => setFilterState(e.target.value)}
            className="flex-1 md:w-40"
          />
          <Button onClick={openAdd} size="md" className="shrink-0">
            <Plus size={15} /> Add
          </Button>
        </div>
      </div>

      <div className="overflow-x-auto -mx-4 md:mx-0 px-4 md:px-0">
        <table className="w-full min-w-[560px] border-collapse text-sm">
          <thead>
            <tr className="border-b-2 border-khaki">
              <th className="text-left py-3 px-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">State</th>
              <th className="text-left py-3 px-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Species</th>
              <th className="text-right py-3 px-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Daily</th>
              <th className="text-right py-3 px-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Possession</th>
              <th className="text-left py-3 px-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Season</th>
              <th className="py-3 px-3 w-20"></th>
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 && (
              <tr>
                <td colSpan={6} className="py-8 text-center text-gray-400 text-sm">
                  No regulations. Add one to enable compliance checking.
                </td>
              </tr>
            )}
            {filtered.map((reg) => (
              <tr key={reg.id} className="border-b border-khaki hover:bg-white/60 transition-colors min-h-[44px]">
                <td className="py-3 px-3 font-medium text-olive">{reg.states?.name}</td>
                <td className="py-3 px-3 text-gray-700">{reg.species?.name}</td>
                <td className="py-3 px-3 text-right tabular-nums font-semibold">{reg.daily_limit}</td>
                <td className="py-3 px-3 text-right tabular-nums font-semibold">{reg.possession_limit}</td>
                <td className="py-3 px-3 text-gray-500 text-xs">
                  {reg.season_start && reg.season_end
                    ? `${reg.season_start} – ${reg.season_end}`
                    : reg.season_start || '—'}
                </td>
                <td className="py-3 px-3">
                  <div className="flex items-center gap-1 justify-end">
                    <button
                      onClick={() => openEdit(reg)}
                      className="p-1.5 text-gray-400 hover:text-olive transition-colors rounded"
                      title="Edit"
                    >
                      <Pencil size={14} />
                    </button>
                    <button
                      onClick={() => setDeleteId(reg.id)}
                      className="p-1.5 text-gray-400 hover:text-rust transition-colors rounded"
                      title="Delete"
                    >
                      <Trash2 size={14} />
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Add/Edit Dialog */}
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent title={editId ? 'Edit Regulation' : 'Add Regulation'}>
          <div className="space-y-4">
            <Select
              id="reg-state"
              label="State"
              options={states.map(s => ({ value: s.id, label: s.name }))}
              value={form.state_id}
              onChange={(e) => set('state_id', e.target.value)}
              placeholder="Select state"
              error={errors.state_id}
              disabled={!!editId}
            />
            <Select
              id="reg-species"
              label="Species"
              options={species.map(s => ({ value: s.id, label: s.name }))}
              value={form.species_id}
              onChange={(e) => set('species_id', e.target.value)}
              placeholder="Select species"
              error={errors.species_id}
              disabled={!!editId}
            />
            <div className="grid grid-cols-2 gap-3">
              <Input
                id="daily-limit"
                label="Daily Limit"
                type="number"
                min={1}
                value={form.daily_limit}
                onChange={(e) => set('daily_limit', e.target.value)}
                error={errors.daily_limit}
              />
              <Input
                id="possession-limit"
                label="Possession Limit"
                type="number"
                min={1}
                value={form.possession_limit}
                onChange={(e) => set('possession_limit', e.target.value)}
                error={errors.possession_limit}
              />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <Input
                id="season-start"
                label="Season Start"
                type="date"
                value={form.season_start}
                onChange={(e) => set('season_start', e.target.value)}
              />
              <Input
                id="season-end"
                label="Season End"
                type="date"
                value={form.season_end}
                onChange={(e) => set('season_end', e.target.value)}
              />
            </div>
            <div className="flex gap-3 pt-2">
              <Button onClick={handleSave} disabled={saving} className="flex-1">
                {saving ? 'Saving...' : 'Save'}
              </Button>
              <DialogClose asChild>
                <Button variant="ghost">Cancel</Button>
              </DialogClose>
            </div>
          </div>
        </DialogContent>
      </Dialog>

      {/* Delete confirmation */}
      <Dialog open={!!deleteId} onOpenChange={(o) => !o && setDeleteId(null)}>
        <DialogContent title="Delete Regulation" description="This cannot be undone.">
          <div className="flex gap-3 mt-2">
            <Button variant="danger" onClick={() => deleteId && handleDelete(deleteId)} className="flex-1">
              Delete
            </Button>
            <Button variant="ghost" onClick={() => setDeleteId(null)}>Cancel</Button>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  )
}
