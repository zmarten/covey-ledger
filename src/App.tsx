import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { useAuth } from '@/hooks/useAuth'
import { AppLayout } from '@/components/layout/AppLayout'
import Login from '@/pages/Login'
import Dashboard from '@/pages/Dashboard'
import HarvestEntry from '@/pages/HarvestEntry'
import StateRegulations from '@/pages/StateRegulations'
import SplitTool from '@/pages/SplitTool'
import FreezerInventory from '@/pages/FreezerInventory'
import SeasonHistory from '@/pages/SeasonHistory'

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { user, loading } = useAuth()
  if (loading) return <div className="min-h-screen bg-canvas flex items-center justify-center text-olive text-sm">Loading...</div>
  if (!user) return <Navigate to="/login" replace />
  return <>{children}</>
}

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route
          element={
            <ProtectedRoute>
              <AppLayout />
            </ProtectedRoute>
          }
        >
          <Route path="/" element={<Dashboard />} />
          <Route path="/harvest" element={<HarvestEntry />} />
          <Route path="/regulations" element={<StateRegulations />} />
          <Route path="/split" element={<SplitTool />} />
          <Route path="/freezer" element={<FreezerInventory />} />
          <Route path="/history" element={<SeasonHistory />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  )
}
