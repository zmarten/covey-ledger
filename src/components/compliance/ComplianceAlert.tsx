import { AlertTriangle, CheckCircle, Info } from 'lucide-react'
import { cn } from '@/lib/utils'
import type { ComplianceResult } from '@/types/database'

interface ComplianceAlertProps {
  result: ComplianceResult
}

export function ComplianceAlert({ result }: ComplianceAlertProps) {
  if (result.blocked) {
    return (
      <div className="flex gap-3 p-3 bg-[#fce8e6] border border-rust/30 rounded">
        <AlertTriangle size={16} className="text-rust mt-0.5 shrink-0" />
        <div>
          <p className="text-sm font-semibold text-rust">Entry blocked.</p>
          {result.explanation && (
            <p className="text-sm text-rust/80 mt-0.5">{result.explanation}</p>
          )}
        </div>
      </div>
    )
  }

  if (result.explanation && result.explanation.includes('No regulation')) {
    return (
      <div className="flex gap-3 p-3 bg-[#fef3c7] border border-warn/30 rounded">
        <Info size={16} className="text-warn mt-0.5 shrink-0" />
        <p className="text-sm text-warn">{result.explanation}</p>
      </div>
    )
  }

  const hasRemainingInfo = result.dailyRemaining !== null || result.possessionRemaining !== null

  return (
    <div className="flex gap-3 p-3 bg-[#e6f0e8] border border-forest/30 rounded">
      <CheckCircle size={16} className="text-forest mt-0.5 shrink-0" />
      <div>
        <p className="text-sm font-semibold text-forest">Entry recorded.</p>
        {hasRemainingInfo && (
          <p className={cn('text-sm text-forest/80 mt-0.5 tabular-nums')}>
            {result.dailyRemaining !== null && `Daily remaining: ${result.dailyRemaining}.`}
            {result.dailyRemaining !== null && result.possessionRemaining !== null && ' '}
            {result.possessionRemaining !== null && `Possession remaining: ${result.possessionRemaining}.`}
          </p>
        )}
      </div>
    </div>
  )
}
