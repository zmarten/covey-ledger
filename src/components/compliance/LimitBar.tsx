import { limitLevel, limitPct } from '@/lib/utils'
import { cn } from '@/lib/utils'

interface LimitBarProps {
  used: number
  limit: number | null
  label?: string
  showNumbers?: boolean
}

export function LimitBar({ used, limit, label, showNumbers = true }: LimitBarProps) {
  const level = limitLevel(used, limit)
  const pct = limitPct(used, limit)

  const trackColor = 'bg-khaki'
  const fillColor = {
    ok: 'bg-forest',
    warn: 'bg-warn',
    blocked: 'bg-rust',
  }[level]

  return (
    <div className="space-y-1">
      {(label || showNumbers) && (
        <div className="flex justify-between items-baseline">
          {label && <span className="text-xs font-medium text-gray-600">{label}</span>}
          {showNumbers && (
            <span
              className={cn(
                'text-xs font-semibold tabular-nums',
                level === 'ok' && 'text-forest',
                level === 'warn' && 'text-warn',
                level === 'blocked' && 'text-rust'
              )}
            >
              {used}{limit !== null ? ` / ${limit}` : ''}
            </span>
          )}
        </div>
      )}
      <div className={cn('h-2 rounded-sm overflow-hidden', trackColor)}>
        <div
          className={cn('h-full rounded-sm transition-all duration-200', fillColor)}
          style={{ width: `${pct}%` }}
        />
      </div>
    </div>
  )
}
