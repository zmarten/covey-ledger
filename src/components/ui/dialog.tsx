import * as RadixDialog from '@radix-ui/react-dialog'
import { X } from 'lucide-react'
import { cn } from '@/lib/utils'

export const Dialog = RadixDialog.Root
export const DialogTrigger = RadixDialog.Trigger
export const DialogClose = RadixDialog.Close

interface DialogContentProps extends React.ComponentPropsWithoutRef<typeof RadixDialog.Content> {
  title: string
  description?: string
}

export function DialogContent({ title, description, children, className, ...props }: DialogContentProps) {
  return (
    <RadixDialog.Portal>
      <RadixDialog.Overlay className="fixed inset-0 bg-black/40 z-40" />
      <RadixDialog.Content
        className={cn(
          'fixed left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 z-50',
          'bg-white border border-[#ccc8be] rounded shadow-lg',
          'w-full max-w-md p-6 focus:outline-none',
          className
        )}
        {...props}
      >
        <div className="flex items-start justify-between mb-4">
          <div>
            <RadixDialog.Title className="text-[18px] font-semibold text-olive">
              {title}
            </RadixDialog.Title>
            {description && (
              <RadixDialog.Description className="text-sm text-gray-500 mt-1">
                {description}
              </RadixDialog.Description>
            )}
          </div>
          <RadixDialog.Close className="ml-4 text-gray-400 hover:text-olive transition-colors">
            <X size={18} />
          </RadixDialog.Close>
        </div>
        {children}
      </RadixDialog.Content>
    </RadixDialog.Portal>
  )
}
