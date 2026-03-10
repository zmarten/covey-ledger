import { forwardRef } from 'react'
import { cn } from '@/lib/utils'

interface SelectProps extends React.SelectHTMLAttributes<HTMLSelectElement> {
  label?: string
  error?: string
  options: { value: string; label: string }[]
  placeholder?: string
}

export const Select = forwardRef<HTMLSelectElement, SelectProps>(
  ({ className, label, error, id, options, placeholder, ...props }, ref) => {
    return (
      <div className="flex flex-col gap-1">
        {label && (
          <label htmlFor={id} className="text-sm font-medium text-olive">
            {label}
          </label>
        )}
        <select
          ref={ref}
          id={id}
          className={cn(
            'h-11 w-full rounded border border-[#ccc8be] bg-white px-3 text-sm text-gray-900',
            'focus:outline-none focus:ring-2 focus:ring-olive focus:border-olive',
            'disabled:bg-khaki disabled:opacity-60',
            'appearance-none cursor-pointer',
            error && 'border-rust focus:ring-rust',
            className
          )}
          style={{ backgroundImage: `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath fill='%233A4A2A' d='M6 8L1 3h10z'/%3E%3C/svg%3E")`, backgroundRepeat: 'no-repeat', backgroundPosition: 'right 12px center' }}
          {...props}
        >
          {placeholder && (
            <option value="" disabled>
              {placeholder}
            </option>
          )}
          {options.map((opt) => (
            <option key={opt.value} value={opt.value}>
              {opt.label}
            </option>
          ))}
        </select>
        {error && <p className="text-xs text-rust">{error}</p>}
      </div>
    )
  }
)
Select.displayName = 'Select'
