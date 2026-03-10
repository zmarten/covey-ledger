import { useState, useEffect } from 'react'
import { supabase } from '@/lib/supabase'
import { useAuth } from '@/hooks/useAuth'
import { today } from '@/lib/utils'
import type { AppState, AppSpecies, ComplianceResult } from '@/types/database'
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Select } from '@/components/ui/select'
import { ComplianceAlert } from '@/components/compliance/ComplianceAlert'

interface FormState {
  state_id: string
  species_id: string
  quantity: string
  date: string
  notes: string
}

const EMPTY_FORM: FormState = {
  state_id: '',
  species_id: '',
  quantity: '',
  date: today(),
  notes: '',
}

export default function HarvestEntry() {
  const { user } = useAuth()
  const [states, setStates] = useState<AppState[]>([])
  const [species, setSpecies] = useState<AppSpecies[]>([])
  const [form, setForm] = useState<FormState>({ ...EMPTY_FORM, state_id: localStorage.getItem('covey_active_state') ?? '' })
  const [errors, setErrors] = useState<Partial<FormState>>({})
  const [submitting, setSubmitting] = useState(false)
  const [complianceResult, setComplianceResult] = useState<ComplianceResult | null>(null)
  const [saved, setSaved] = useState(false)

  useEffect(() => {
    Promise.all([
      supabase.from('states').select('*').order('name'),
      supabase.from('species').select('*').order('name'),
    ]).then(([statesRes, speciesRes]) => {
      if (statesRes.data) setStates(statesRes.data)
      if (speciesRes.data) setSpecies(speciesRes.data)
    })
  }, [])

  function set(field: keyof FormState, value: string) {
    setForm(f => ({ ...f, [field]: value }))
    setErrors(e => ({ ...e, [field]: '' }))
    setComplianceResult(null)
    setSaved(false)
  }

  function validate(): boolean {
    const e: Partial<FormState> = {}
    if (!form.state_id) e.state_id = 'Required'
    if (!form.species_id) e.species_id = 'Required'
    if (!form.quantity || Number(form.quantity) < 1) e.quantity = 'Enter a valid quantity'
    if (!form.date) e.date = 'Required'
    setErrors(e)
    return Object.keys(e).length === 0
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!validate()) return
    setSubmitting(true)
    setComplianceResult(null)

    // Step 1: Server-side compliance check
    const { data: result, error: rpcError } = await supabase.rpc('validate_harvest_entry', {
      p_state_id: form.state_id,
      p_species_id: form.species_id,
      p_quantity: Number(form.quantity),
      p_date: form.date,
    })

    if (rpcError || !result) {
      setErrors({ quantity: rpcError?.message ?? 'Compliance check failed.' })
      setSubmitting(false)
      return
    }

    const compliance = result as unknown as ComplianceResult
    setComplianceResult(compliance)

    if (compliance.blocked) {
      setSubmitting(false)
      return
    }

    // Step 2: Persist entry
    const { error: insertError } = await supabase.from('harvest_entries').insert({
      user_id: user!.id,
      state_id: form.state_id,
      species_id: form.species_id,
      quantity: Number(form.quantity),
      date: form.date,
      notes: form.notes || null,
    })

    if (insertError) {
      setErrors({ quantity: insertError.message })
    } else {
      setSaved(true)
      localStorage.setItem('covey_active_state', form.state_id)
      setForm({ ...EMPTY_FORM, state_id: form.state_id, date: form.date })
    }

    setSubmitting(false)
  }

  return (
    <div className="page-container max-w-xl">
      <div className="mb-6">
        <h1 className="text-[32px] font-bold text-olive">Log Harvest</h1>
        <p className="text-gray-500 text-sm">Compliance is checked server-side before the entry is recorded.</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>New Entry</CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <Select
              id="state"
              label="State"
              options={states.map(s => ({ value: s.id, label: s.name }))}
              value={form.state_id}
              onChange={(e) => set('state_id', e.target.value)}
              placeholder="Select state"
              error={errors.state_id}
            />
            <Select
              id="species"
              label="Species"
              options={species.map(s => ({ value: s.id, label: s.name }))}
              value={form.species_id}
              onChange={(e) => set('species_id', e.target.value)}
              placeholder="Select species"
              error={errors.species_id}
            />
            <Input
              id="quantity"
              label="Quantity"
              type="number"
              min={1}
              max={99}
              value={form.quantity}
              onChange={(e) => set('quantity', e.target.value)}
              placeholder="0"
              error={errors.quantity}
            />
            <Input
              id="date"
              label="Date"
              type="date"
              value={form.date}
              onChange={(e) => set('date', e.target.value)}
              error={errors.date}
            />
            <div className="flex flex-col gap-1">
              <label htmlFor="notes" className="text-sm font-medium text-olive">Notes (optional)</label>
              <textarea
                id="notes"
                value={form.notes}
                onChange={(e) => set('notes', e.target.value)}
                placeholder="Field conditions, location, etc."
                rows={2}
                className="w-full rounded border border-[#ccc8be] bg-white px-3 py-2 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-olive focus:border-olive resize-none"
              />
            </div>

            {complianceResult && !saved && (
              <ComplianceAlert result={complianceResult} />
            )}

            {saved && complianceResult && (
              <ComplianceAlert result={{ ...complianceResult, blocked: false }} />
            )}

            <div className="flex gap-3 pt-2">
              <Button type="submit" disabled={submitting} size="md" className="flex-1">
                {submitting ? 'Checking...' : 'Save Entry'}
              </Button>
              <Button
                type="button"
                variant="ghost"
                size="md"
                onClick={() => {
                  setForm({ ...EMPTY_FORM, state_id: form.state_id })
                  setComplianceResult(null)
                  setSaved(false)
                  setErrors({})
                }}
              >
                Clear
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  )
}
