import { forwardRef } from 'react'
import { Slot } from '@radix-ui/react-slot'
import { cva, type VariantProps } from 'class-variance-authority'
import { cn } from '@/lib/utils'

const buttonVariants = cva(
  'inline-flex items-center justify-center gap-2 font-medium text-sm transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-olive disabled:pointer-events-none disabled:opacity-50 cursor-pointer',
  {
    variants: {
      variant: {
        primary: 'bg-olive text-canvas hover:bg-olive-dark border border-olive',
        secondary: 'bg-khaki text-olive border border-khaki hover:bg-[#ddd8cc]',
        accent: 'bg-burnt text-white hover:bg-burnt-dark border border-burnt',
        danger: 'bg-rust text-white hover:bg-rust-light border border-rust',
        ghost: 'bg-transparent text-olive hover:bg-khaki border border-transparent',
        outline: 'bg-transparent text-olive border border-olive hover:bg-khaki',
      },
      size: {
        sm: 'h-8 px-3 text-xs rounded',
        md: 'h-11 px-4 rounded min-h-[44px]',
        lg: 'h-12 px-6 text-base rounded min-h-[44px]',
        icon: 'h-9 w-9 rounded',
      },
    },
    defaultVariants: {
      variant: 'primary',
      size: 'md',
    },
  }
)

interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : 'button'
    return (
      <Comp
        ref={ref}
        className={cn(buttonVariants({ variant, size, className }))}
        {...props}
      />
    )
  }
)
Button.displayName = 'Button'
