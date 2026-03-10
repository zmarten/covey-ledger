import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function formatDate(date: string | Date): string {
  const d = typeof date === 'string' ? new Date(date + 'T00:00:00') : date
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
}

export function today(): string {
  return new Date().toISOString().split('T')[0]
}

/** Returns warning level based on percentage used */
export function limitLevel(used: number, limit: number | null): 'ok' | 'warn' | 'blocked' {
  if (limit === null) return 'ok'
  const pct = used / limit
  if (pct >= 1) return 'blocked'
  if (pct >= 0.8) return 'warn'
  return 'ok'
}

export function limitPct(used: number, limit: number | null): number {
  if (!limit) return 0
  return Math.min((used / limit) * 100, 100)
}
