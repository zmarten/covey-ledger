import { cn } from '@/lib/utils'

interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  children: React.ReactNode
}

export function Card({ className, children, ...props }: CardProps) {
  return (
    <div
      className={cn('bg-white border border-[#ccc8be] rounded p-4', className)}
      {...props}
    >
      {children}
    </div>
  )
}

export function CardHeader({ className, children, ...props }: CardProps) {
  return (
    <div className={cn('mb-3 pb-3 border-b border-khaki', className)} {...props}>
      {children}
    </div>
  )
}

export function CardTitle({ className, children, ...props }: CardProps) {
  return (
    <h4 className={cn('text-[18px] font-semibold text-olive', className)} {...props}>
      {children}
    </h4>
  )
}

export function CardContent({ className, children, ...props }: CardProps) {
  return (
    <div className={cn('', className)} {...props}>
      {children}
    </div>
  )
}
