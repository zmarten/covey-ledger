import { createClient } from '@supabase/supabase-js'

export type WaitlistInput = {
  email: string
  statesHunted?: string
  toolsUsed?: string
  biggestPain?: string
  source?: string
}

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

declare global {
  interface Window {
    gtag?: (event: 'event', action: string, params?: Record<string, unknown>) => void
    plausible?: (eventName: string, options?: { props?: Record<string, unknown> }) => void
  }
}

export async function joinWaitlist(input: WaitlistInput) {
  const supabaseUrl = import.meta.env.VITE_SUPABASE_URL as string | undefined
  const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined
  const email = input.email.trim().toLowerCase()

  if (!EMAIL_PATTERN.test(email)) {
    throw new Error('Please enter a valid email address.')
  }

  if (!supabaseUrl || !supabaseAnonKey) {
    trackWaitlistEvent('waitlist_manual_email_fallback', input.source ?? 'landing')
    throw new Error('Waitlist is not configured yet. Please email zachdmartens@gmail.com for early access.')
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey)
  const { error } = await supabase
    .from('waitlist_signups')
    .insert({
      email,
      states_hunted: normalizeOptional(input.statesHunted),
      tools_used: normalizeOptional(input.toolsUsed),
      biggest_pain: normalizeOptional(input.biggestPain),
      source: input.source ?? 'landing',
      updated_at: new Date().toISOString(),
    })

  // Unique email means the visitor is already on the list; treat as success.
  if (error && error.code !== '23505') {
    trackWaitlistEvent('waitlist_submit_error', input.source ?? 'landing')
    throw new Error('Could not save your request. Please try again or email zachdmartens@gmail.com.')
  }

  trackWaitlistEvent(error?.code === '23505' ? 'waitlist_duplicate_email' : 'waitlist_submit_success', input.source ?? 'landing')
}

function normalizeOptional(value?: string) {
  return value?.trim() || null
}

function trackWaitlistEvent(eventName: string, source: string) {
  try {
    window.plausible?.(eventName, { props: { source } })
    window.gtag?.('event', eventName, { source })
  } catch {
    // Analytics should never block waitlist submission.
  }
}
