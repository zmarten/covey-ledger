import { NavLink } from 'react-router-dom'
import { LayoutDashboard, BookOpen, Scroll, Users, Package, Clock } from 'lucide-react'
import { cn } from '@/lib/utils'

const navItems = [
  { to: '/app', label: 'Dashboard', icon: LayoutDashboard, end: true },
  { to: '/app/harvest', label: 'Log', icon: BookOpen },
  { to: '/app/freezer', label: 'Freezer', icon: Package },
  { to: '/app/split', label: 'Split', icon: Users },
  { to: '/app/regulations', label: 'Regs', icon: Scroll },
  { to: '/app/history', label: 'History', icon: Clock },
]

export function BottomNav() {
  return (
    <nav className="fixed bottom-0 left-0 right-0 z-50 bg-olive border-t border-olive-light flex md:hidden"
      style={{ paddingBottom: 'env(safe-area-inset-bottom)' }}
    >
      {navItems.map(({ to, label, icon: Icon, end }) => (
        <NavLink
          key={to}
          to={to}
          end={end}
          className={({ isActive }) =>
            cn(
              'flex-1 flex flex-col items-center justify-center py-2 gap-0.5 text-[10px] font-medium transition-colors min-h-[52px]',
              isActive ? 'text-canvas' : 'text-canvas/50'
            )
          }
        >
          <Icon size={20} />
          {label}
        </NavLink>
      ))}
    </nav>
  )
}
