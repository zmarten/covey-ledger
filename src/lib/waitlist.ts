import { createClient } from '@supabase/supabase-js'

export type WaitlistInput = {
  email: string
  statesHunted?: string
  toolsUsed?: string
  biggestPain?: string
  source?: string
}

export async function joinWaitlist(input: WaitlistInput) {
  const supabaseUrl = import.meta.env.VITE_SUPABASE_URL as string | undefined
  const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined

  if (!supabaseUrl || !supabaseAnonKey) {
    throw new Error('Waitlist is not configured yet. Please email zachdmartens@gmail.com for early access.')
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey)
  const { error } = await supabase
    .from('waitlist_signups')
    .insert({
      email: input.email.trim().toLowerCase(),
      states_hunted: input.statesHunted?.trim() || null,
      tools_used: input.toolsUsed?.trim() || null,
      biggest_pain: input.biggestPain?.trim() || null,
      source: input.source ?? 'landing',
      updated_at: new Date().toISOString(),
    })

  if (error && error.code !== '23505') {
    throw new Error(error.message)
  }
}
