import { forwardRef } from 'react'
import { cn } from '@/lib/utils'

interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label?: string
  error?: string
}

export const Input = forwardRef<HTMLInputElement, InputProps>(
  ({ className, label, error, id, ...props }, ref) => {
    return (
      <div className="flex flex-col gap-1">
        {label && (
          <label htmlFor={id} className="text-sm font-medium text-olive">
            {label}
          </label>
        )}
        <input
          ref={ref}
          id={id}
          className={cn(
            'h-11 w-full rounded border border-[#ccc8be] bg-white px-3 text-sm text-gray-900',
            'placeholder:text-gray-400',
            'focus:outline-none focus:ring-2 focus:ring-olive focus:border-olive',
            'disabled:bg-khaki disabled:opacity-60',
            error && 'border-rust focus:ring-rust',
            className
          )}
          {...props}
        />
        {error && <p className="text-xs text-rust">{error}</p>}
      </div>
    )
  }
)
Input.displayName = 'Input'
