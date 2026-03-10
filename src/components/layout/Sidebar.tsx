import { NavLink } from 'react-router-dom'
import {
  LayoutDashboard,
  BookOpen,
  Scroll,
  Users,
  Package,
  Clock,
  LogOut,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import { useAuth } from '@/hooks/useAuth'

const navItems = [
  { to: '/', label: 'Dashboard', icon: LayoutDashboard, end: true },
  { to: '/harvest', label: 'Log Harvest', icon: BookOpen },
  { to: '/regulations', label: 'Regulations', icon: Scroll },
  { to: '/split', label: 'Split Tool', icon: Users },
  { to: '/freezer', label: 'Freezer', icon: Package },
  { to: '/history', label: 'History', icon: Clock },
]

export function Sidebar() {
  const { signOut, user } = useAuth()

  return (
    <aside className="w-56 shrink-0 bg-olive min-h-screen flex flex-col">
      {/* Logo */}
      <div className="px-4 py-5 border-b border-olive-light">
        <p className="text-canvas font-bold text-lg tracking-tight">Covey Ledger</p>
        <p className="text-canvas/50 text-xs mt-0.5 truncate">{user?.email}</p>
      </div>

      {/* Nav */}
      <nav className="flex-1 py-3">
        {navItems.map(({ to, label, icon: Icon, end }) => (
          <NavLink
            key={to}
            to={to}
            end={end}
            className={({ isActive }) =>
              cn(
                'flex items-center gap-3 px-4 py-2.5 text-sm font-medium transition-colors',
                isActive
                  ? 'bg-olive-light text-canvas'
                  : 'text-canvas/70 hover:bg-olive-light hover:text-canvas'
              )
            }
          >
            <Icon size={16} />
            {label}
          </NavLink>
        ))}
      </nav>

      {/* Sign out */}
      <div className="px-4 py-4 border-t border-olive-light">
        <button
          onClick={signOut}
          className="flex items-center gap-2 text-canvas/60 hover:text-canvas text-sm transition-colors w-full"
        >
          <LogOut size={15} />
          Sign out
        </button>
      </div>
    </aside>
  )
}
