import { cn } from '@/lib/utils'

type BadgeVariant = 'ok' | 'warn' | 'blocked' | 'neutral'

interface BadgeProps extends React.HTMLAttributes<HTMLSpanElement> {
  variant?: BadgeVariant
}

const variantClasses: Record<BadgeVariant, string> = {
  ok: 'bg-[#e6f0e8] text-forest border-forest/30',
  warn: 'bg-[#fef3c7] text-warn border-warn/30',
  blocked: 'bg-[#fce8e6] text-rust border-rust/30',
  neutral: 'bg-khaki text-olive border-[#ccc8be]',
}

export function Badge({ variant = 'neutral', className, children, ...props }: BadgeProps) {
  return (
    <span
      className={cn(
        'inline-flex items-center px-2 py-0.5 text-xs font-medium rounded border',
        variantClasses[variant],
        className
      )}
      {...props}
    >
      {children}
    </span>
  )
}
